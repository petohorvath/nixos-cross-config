/*
  Resolves and places contributions at destinations: option paths on the
  receiver where contributions' definitions go.

  Resolution has two phases. Structural resolution walks the receiver's
  declarations and is safe while receiving attribute names are built. Deep
  resolution re-evaluates the receiver through `extendModules` to inspect
  submodule instances, so it may only be forced inside a matched option's
  value; forcing it earlier makes the names recurse.
*/
{
  extendModules,
  lib,
  optionPaths,
  options,
  specialArgs,
}:
let
  # Paths whose destinations enclosing evaluations are inspecting; each
  # inspection re-evaluates the receiver without receiving at its own path.
  inspectionPaths = specialArgs.__nixosCrossConfigInspectionPaths or [ ];

  restoreDefinitionProperties = import ./restore-definition-properties.nix { inherit lib; };

  # Returns `{ prefix, remaining, option }` for the first option on the path,
  # or null when no declaration matches.
  findDeclaration =
    prefix: remaining: declarations:
    if lib.isOption declarations then
      {
        inherit prefix remaining;
        option = declarations;
      }
    else if remaining == [ ] then
      null
    else
      let
        segment = builtins.head remaining;
      in
      findDeclaration (prefix ++ [ segment ]) (builtins.tail remaining) (declarations.${segment} or { });

  /*
    Evaluates a writable tag or a type probe at its full path in isolation.
    The path preserves submodule names and nested `_module` options. Each
    definition gets its own module: `lib.mkDefinition` directly on a
    submodule-typed option leaves its marker on the record, which submodule
    merging rejects.
  */
  evaluateOption =
    {
      prefix,
      option,
      definitions,
    }:
    let
      declarations = option.declarations or [ ];

      declarationModule =
        lib.optionalAttrs (declarations != [ ]) {
          _file = builtins.head declarations;
        }
        // {
          options = lib.setAttrByPath prefix option;
        };

      definitionModule = definition: {
        _file = definition.file;
        config = lib.setAttrByPath prefix definition.value;
      };

      evaluation = lib.evalModules {
        modules = [ declarationModule ] ++ map definitionModule definitions;
      };
    in
    # Inspection consumes definitions, leaving the final value and apply lazy.
    lib.getAttrFromPath prefix evaluation.options;

  /*
    The `find*` helpers resolve `remaining` below the option at `prefix`.
    They return the destination option, a read-only option on the way, or
    the nearest enclosing option when its type validates `remaining`
    natively. They return null when a tag is missing or a submodule has
    neither a matching declaration nor a freeform type.
  */
  findLocalOption =
    {
      prefix,
      remaining,
      option,
    }:
    if remaining == [ ] || option.readOnly or false then
      option
    else
      findTypeOption {
        inherit prefix remaining;
        inherit (option) type;
        definitions = restoreDefinitionProperties option;
        enclosingOption = option;
      };

  findTypeOption =
    {
      prefix,
      remaining,
      type,
      definitions,
      enclosingOption,
    }:
    let
      probe = evaluateOption {
        inherit prefix;
        option = lib.mkOption { inherit type; };
        definitions = definitions ++ [
          {
            file = "nixos-cross-config destination inspection";
            value = lib.setAttrByPath (lib.init remaining) { };
          }
        ];
      };
    in
    if remaining == [ ] then
      enclosingOption
    else if type.name == "nullOr" || type.name == "unique" then
      findTypeOption {
        inherit enclosingOption prefix remaining;
        type = type.nestedTypes.elemType;
        definitions = builtins.filter (definition: definition.value != null) probe.definitionsWithLocations;
      }
    else if type.name == "attrTag" then
      findTagOption {
        inherit prefix remaining type;
        definitions = probe.definitionsWithLocations;
      }
    else
      findMetadataOption {
        inherit enclosingOption prefix remaining;
        metadata = probe.valueMeta;
      };

  findTagOption =
    {
      prefix,
      remaining,
      type,
      definitions,
    }:
    let
      segment = builtins.head remaining;
      tagPath = prefix ++ [ segment ];
      tag = (type.getSubOptions prefix).${segment} or null;
      childDefinitions = lib.concatMap (
        definition:
        lib.optional (builtins.hasAttr segment definition.value) {
          inherit (definition) file;
          value = definition.value.${segment};
        }
      ) definitions;
    in
    if tag == null then
      null
    else if tag.readOnly or false then
      tag
    else
      findLocalOption {
        prefix = tagPath;
        remaining = builtins.tail remaining;
        option = evaluateOption {
          prefix = tagPath;
          option = tag;
          definitions = childDefinitions;
        };
      };

  findMetadataOption =
    {
      prefix,
      remaining,
      metadata,
      enclosingOption,
    }:
    if remaining == [ ] then
      enclosingOption
    else if metadata ? configuration then
      findSubmoduleOption {
        inherit enclosingOption prefix remaining;
        inherit (metadata) configuration;
      }
    else if metadata ? attrs then
      let
        segment = builtins.head remaining;
      in
      findMetadataOption {
        prefix = prefix ++ [ segment ];
        remaining = builtins.tail remaining;
        metadata = metadata.attrs.${segment} or { };
        inherit enclosingOption;
      }
    else
      # Types without submodule metadata validate their attribute contents
      # natively.
      enclosingOption;

  findSubmoduleOption =
    {
      prefix,
      remaining,
      configuration,
      enclosingOption,
    }:
    let
      # The empty prefix stub may name an absent child; inspect declarations
      # first.
      instance = configuration.extendModules {
        modules = [ { _module.check = false; } ];
      };
      declaration = findDeclaration prefix remaining instance.options;
      freeformType = instance._module.freeformType;
    in
    if declaration != null then
      findLocalOption {
        inherit (declaration) option prefix remaining;
      }
    else if freeformType != null then
      findTypeOption {
        inherit enclosingOption prefix remaining;
        type = freeformType;
        definitions = [
          {
            file = "nixos-cross-config freeform destination inspection";
            value = removeAttrs instance.config (builtins.attrNames instance.options);
          }
        ];
      }
    else
      null;

  /*
    Resolves `path` below its structural declaration. Only paths below a
    writable option need the receiver evaluated again, without receiving our
    own contribution at `path`, so that receiver-local submodule definitions
    decide the destination.
  */
  resolveDestination =
    path:
    let
      resolveBelow =
        {
          prefix,
          remaining,
          option,
        }:
        if remaining == [ ] || option.readOnly or false then
          option
        else
          findLocalOption {
            inherit prefix remaining;
            option =
              lib.getAttrFromPath prefix
                (extendModules {
                  specialArgs.__nixosCrossConfigInspectionPaths = inspectionPaths ++ [ path ];
                }).options;
          };
    in
    lib.mapNullable resolveBelow (findDeclaration [ ] path options);

  # Placement and assertions share each path's deep resolution.
  resolvedDestinations = lib.pipe optionPaths [
    (map (path: lib.nameValuePair (builtins.toJSON path) (resolveDestination path)))
    builtins.listToAttrs
  ];
  resolvedDestination = path: resolvedDestinations.${builtins.toJSON path};

  statusOf =
    option:
    if option == null then
      "missing"
    else if option.readOnly or false then
      "read-only"
    else
      "writable";

  isWritable = option: statusOf option == "writable";
in
{
  # Whether this evaluation inspects destinations for an enclosing one.
  isInspecting = inspectionPaths != [ ];

  /*
    Places definitions at a destination.

    Inputs:
    - path: an allowed option path.
    - definitions: the definitions contributed at `path`.

    Returns a receiver configuration fragment. Its attribute names come from
    the receiver's declarations alone; the deep writability check stays
    inside the matched option's value. The fragment is empty for a path
    whose destination this evaluation is inspecting.
  */
  receivingDefinition =
    path: definitions:
    let
      destination = resolvedDestination path;

      mergeAtOption =
        remaining:
        if remaining == [ ] then
          lib.mkMerge definitions
        else
          # A false `lib.mkIf` would still push its attributes into the path;
          # an empty merge defines none.
          lib.mkMerge (
            lib.optional (isWritable destination) (lib.setAttrByPath remaining (lib.mkMerge definitions))
          );

      # Repeats the structural walk so attribute names never force deep
      # resolution.
      mkPathDefinitions =
        remaining: declarations:
        if remaining == [ ] then
          { }
        else
          let
            segment = builtins.head remaining;
            rest = builtins.tail remaining;
            declaration = declarations.${segment} or null;
          in
          lib.optionalAttrs (declaration != null && (!lib.isOption declaration || isWritable declaration)) {
            ${segment} =
              if lib.isOption declaration then mergeAtOption rest else mkPathDefinitions rest declaration;
          };
    in
    if builtins.elem path inspectionPaths then { } else mkPathDefinitions path options;

  /*
    Classifies a destination for assertions.

    Inputs:
    - path: an allowed option path.

    Returns "writable", "missing", or "read-only".
  */
  status = path: statusOf (resolvedDestination path);
}
