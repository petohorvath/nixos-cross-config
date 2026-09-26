{
  extendModules,
  inspectionPaths,
  lib,
  options,
}:
path:
let
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
    They return the destination option, the nearest enclosing option when
    its type validates the rest natively, or null when no declaration or
    tag matches.
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

  destination = findDeclaration [ ] path options;

  receiverLocalOption =
    let
      # Inspect local submodule definitions without receiving our own
      # contribution.
      localOptions =
        (extendModules {
          specialArgs.__nixosCrossConfigInspectionPaths = inspectionPaths ++ [ path ];
        }).options;
    in
    findLocalOption {
      inherit (destination) prefix remaining;
      option = lib.getAttrFromPath destination.prefix localOptions;
    };

  requiresLocalInspection = destination.remaining != [ ] && !(destination.option.readOnly or false);
in
if destination == null then
  null
else if requiresLocalInspection then
  receiverLocalOption
else
  destination.option
