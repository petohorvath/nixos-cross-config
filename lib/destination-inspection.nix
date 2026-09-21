{
  extendModules,
  inspectionPaths,
  lib,
  options,
}:
let
  findReceivingOption =
    path:
    let
      destination = findDeclaration [ ] path options;
    in
    if destination == null then
      null
    else if destination.remaining == [ ] || destination.option.readOnly or false then
      destination.option
    else
      # Inspect local submodule definitions without receiving our own contribution.
      let
        localOptions =
          (extendModules {
            specialArgs.__nixosCrossConfigInspectPaths = inspectionPaths ++ [ path ];
          }).options;
      in
      findLocalOption destination.prefix destination.remaining (
        lib.getAttrFromPath destination.prefix localOptions
      );

  findLocalOption =
    prefix: remaining: option:
    if remaining == [ ] || option.readOnly or false then
      option
    else
      findTypeOption prefix remaining option.type (restoreDefinitionProperties option) option;

  findTypeOption =
    prefix: path: type: definitions: owner:
    let
      probe = lib.modules.mergeDefinitions prefix type (
        definitions
        ++ [
          {
            file = "nixos-cross-config destination inspection";
            value = lib.setAttrByPath (lib.init path) { };
          }
        ]
      );
    in
    if path == [ ] then
      owner
    else if type.name == "nullOr" || type.name == "unique" then
      findTypeOption prefix path type.nestedTypes.elemType (builtins.filter (
        definition: definition.value != null
      ) probe.defsFinal) owner
    else if type.name == "attrTag" then
      let
        segment = builtins.head path;
        tag = (type.getSubOptions prefix).${segment} or null;
        childDefinitions = lib.concatMap (
          definition:
          lib.optional (builtins.hasAttr segment definition.value) {
            inherit (definition) file;
            value = definition.value.${segment};
          }
        ) probe.defsFinal;
      in
      if tag == null then
        null
      else if tag.readOnly or false then
        tag
      else
        findLocalOption (prefix ++ [ segment ]) (builtins.tail path) (evaluateTagOption {
          optionPath = prefix ++ [ segment ];
          inherit tag;
          definitions = childDefinitions;
        })
    else
      findMetadataOption prefix path probe.checkedAndMerged.valueMeta owner;

  evaluateTagOption =
    {
      optionPath,
      tag,
      definitions,
    }:
    let
      evaluation = lib.evalModules {
        modules = [
          (
            lib.optionalAttrs (tag.declarations != [ ]) {
              _file = builtins.head tag.declarations;
            }
            // {
              # The full path preserves submodule names and nested `_module` tags.
              options = lib.setAttrByPath optionPath tag;
              config = lib.setAttrByPath optionPath (lib.mkMerge (map lib.mkDefinition definitions));
            }
          )
        ];
      };
    in
    # Inspection consumes definitions, leaving the final value and apply lazy.
    lib.getAttrFromPath optionPath evaluation.options;

  findMetadataOption =
    prefix: path: metadata: owner:
    if path == [ ] then
      owner
    else if metadata ? configuration then
      let
        # The empty prefix stub may name an absent child; inspect declarations first.
        instance = metadata.configuration.extendModules {
          modules = [ { _module.check = false; } ];
        };
        destination = findDeclaration prefix path instance.options;
        freeformType = instance._module.freeformType;
      in
      if destination != null then
        findLocalOption destination.prefix destination.remaining destination.option
      else if freeformType != null then
        findTypeOption prefix path freeformType [
          {
            file = "nixos-cross-config freeform destination inspection";
            value = removeAttrs instance.config (builtins.attrNames instance.options);
          }
        ] owner
      else
        null
    else if metadata ? attrs then
      let
        segment = builtins.head path;
      in
      findMetadataOption (prefix ++ [ segment ]) (builtins.tail path) (metadata.attrs.${segment} or { }
      ) owner
    else
      # Types without submodule metadata validate their attribute contents natively.
      owner;

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

  restoreDefinitionProperties = import ./restore-definition-properties.nix { inherit lib; };
in
findReceivingOption
