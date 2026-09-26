{
  extendModules,
  inspectionPaths,
  lib,
  options,
}:
path:
let
  restoreDefinitionProperties = import ./restore-definition-properties.nix { inherit lib; };

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
      optionPath,
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
          options = lib.setAttrByPath optionPath option;
        };

      definitionModule = definition: {
        _file = definition.file;
        config = lib.setAttrByPath optionPath definition.value;
      };

      evaluation = lib.evalModules {
        modules = [ declarationModule ] ++ map definitionModule definitions;
      };
    in
    # Inspection consumes definitions, leaving the final value and apply lazy.
    lib.getAttrFromPath optionPath evaluation.options;

  findLocalOption =
    {
      prefix,
      path,
      option,
    }:
    if path == [ ] || option.readOnly or false then
      option
    else
      findTypeOption {
        inherit path prefix;
        inherit (option) type;
        definitions = restoreDefinitionProperties option;
        enclosingOption = option;
      };

  findTypeOption =
    {
      prefix,
      path,
      type,
      definitions,
      enclosingOption,
    }:
    let
      probe = evaluateOption {
        optionPath = prefix;
        option = lib.mkOption { inherit type; };
        definitions = definitions ++ [
          {
            file = "nixos-cross-config destination inspection";
            value = lib.setAttrByPath (lib.init path) { };
          }
        ];
      };
    in
    if path == [ ] then
      enclosingOption
    else if type.name == "nullOr" || type.name == "unique" then
      findTypeOption {
        inherit enclosingOption path prefix;
        type = type.nestedTypes.elemType;
        definitions = builtins.filter (definition: definition.value != null) probe.definitionsWithLocations;
      }
    else if type.name == "attrTag" then
      findTagOption {
        inherit path prefix type;
        definitions = probe.definitionsWithLocations;
      }
    else
      findMetadataOption {
        inherit enclosingOption path prefix;
        metadata = probe.valueMeta;
      };

  findTagOption =
    {
      prefix,
      path,
      type,
      definitions,
    }:
    let
      segment = builtins.head path;
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
        path = builtins.tail path;
        option = evaluateOption {
          optionPath = tagPath;
          option = tag;
          definitions = childDefinitions;
        };
      };

  findMetadataOption =
    {
      prefix,
      path,
      metadata,
      enclosingOption,
    }:
    if path == [ ] then
      enclosingOption
    else if metadata ? configuration then
      findSubmoduleOption {
        inherit enclosingOption path prefix;
        inherit (metadata) configuration;
      }
    else if metadata ? attrs then
      let
        segment = builtins.head path;
      in
      findMetadataOption {
        prefix = prefix ++ [ segment ];
        path = builtins.tail path;
        metadata = metadata.attrs.${segment} or { };
        inherit enclosingOption;
      }
    else
      /*
        Types without submodule metadata validate their attribute contents
        natively.
      */
      enclosingOption;

  findSubmoduleOption =
    {
      prefix,
      path,
      configuration,
      enclosingOption,
    }:
    let
      /*
        The empty prefix stub may name an absent child; inspect declarations
        first.
      */
      instance = configuration.extendModules {
        modules = [ { _module.check = false; } ];
      };
      destination = findDeclaration prefix path instance.options;
      freeformType = instance._module.freeformType;
    in
    if destination != null then
      findLocalOption {
        inherit (destination) option prefix;
        path = destination.remaining;
      }
    else if freeformType != null then
      findTypeOption {
        inherit enclosingOption path prefix;
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

  inspectReceiverLocalOption =
    { destination, path }:
    let
      /*
        Inspect local submodule definitions without receiving our own
        contribution.
      */
      localOptions =
        (extendModules {
          specialArgs.__nixosCrossConfigInspectPaths = inspectionPaths ++ [ path ];
        }).options;
    in
    findLocalOption {
      inherit (destination) prefix;
      path = destination.remaining;
      option = lib.getAttrFromPath destination.prefix localOptions;
    };

  destination = findDeclaration [ ] path options;

  requiresLocalInspection = destination.remaining != [ ] && !(destination.option.readOnly or false);
in
if destination == null then
  null
else if requiresLocalInspection then
  inspectReceiverLocalOption {
    inherit destination path;
  }
else
  destination.option
