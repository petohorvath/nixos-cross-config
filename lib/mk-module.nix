/*
  Forwards definitions at a shared set of option paths between NixOS nodes.
  Each participant imports mkModule { inherit name nodes optionPaths; }, where
  nodes.<name>.config is the caller's evaluated NixOS configuration.
*/
{
  name,
  nodes,
  optionPaths,
}:
{
  config,
  extendModules,
  lib,
  options,
  specialArgs,
  ...
}:
let
  module = {
    options.crossConfig.nodes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule mkContributionModule);
      default = { };
      description = "Configuration contributions indexed by receiver node identity.";
      apply = lib.mapAttrs (
        receiver: contribution:
        let
          context = "while evaluating contributions from sender `${name}` to receiver `${receiver}`:";
        in
        builtins.addErrorContext context contribution._definitions
      );
    };

    # Only declared receiving options enter the module's configuration structure.
    config = lib.pipe (builtins.filter (path: !(builtins.elem path inspectionPaths)) optionPaths) [
      (map mkReceivingDefinition)
      (
        definitions:
        definitions
        ++ lib.optional (inspectionPaths == [ ]) {
          assertions =
            map mkDestinationAssertion optionPaths
            ++ lib.mapAttrsToList (receiver: contribution: {
              assertion = builtins.seq contribution (builtins.hasAttr receiver nodes);
              message = "nixos-cross-config: sender `${name}` targets unknown receiver `${receiver}`.";
            }) config.crossConfig.nodes;
        }
      )
      lib.mkMerge
    ];
  };

  inspectionPaths = specialArgs.__nixosCrossConfigInspectPaths or [ ];

  mkContributionModule =
    { options, ... }:
    {
      options =
        mkPathAttrs (
          path:
          lib.mkOption {
            type = lib.types.raw;
            description = "Definitions contributed to ${lib.showOption path}.";
          }
        )
        // {
          _definitions = lib.mkOption {
            type = lib.types.raw;
            internal = true;
            visible = false;
            readOnly = true;
            description = "Outgoing definitions before the receiving type merges them.";
            # Inspect definitions without forcing a merge in the sender.
            default = mkPathAttrs (path: restoreDefinitionProperties (lib.getAttrFromPath path options));
          };
        };
    };

  mkReceivingDefinition =
    path:
    let
      definitions = collectDefinitions path;
      mkPath =
        remaining: declarations:
        if remaining == [ ] then
          { }
        else
          let
            segment = builtins.head remaining;
            rest = builtins.tail remaining;
            destination = declarations.${segment} or null;
            option = findReceivingOption path;
          in
          lib.optionalAttrs
            (destination != null && (!lib.isOption destination || !(destination.readOnly or false)))
            {
              ${segment} =
                if lib.isOption destination then
                  if rest == [ ] then
                    lib.mkMerge definitions
                  else
                    # Inspect instances only inside their declared writable option.
                    lib.mkMerge (
                      lib.optional (option != null && !(option.readOnly or false)) (
                        lib.setAttrByPath rest (lib.mkMerge definitions)
                      )
                    )
                else
                  mkPath rest destination;
            };
    in
    # Keep declaration inspection below its namespace so module arguments resolve.
    mkPath path options;

  mkDestinationAssertion =
    path:
    let
      option = findReceivingOption path;
      definitions = collectDefinitions path;
      reason = if option == null then "missing" else "read-only";
    in
    {
      assertion = definitions == [ ] || (option != null && !(option.readOnly or false));
      message = ''
        nixos-cross-config: receiver `${name}` has a ${reason} destination `${lib.showOption path}`.
        Contributions: ${lib.concatMapStringsSep ", " (definition: definition.file) definitions}
      '';
    };

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

  collectDefinitions =
    path:
    lib.pipe nodes [
      (lib.mapAttrsToList (
        sender: node:
        map (
          definition:
          lib.mkDefinition {
            file =
              definition.file
              + " (sender `${sender}`, receiver `${name}`,"
              + " destination `${lib.showOption path}`)";
            inherit (definition) value;
          }
        ) (lib.attrByPath path [ ] (node.config.crossConfig.nodes.${name} or { }))
      ))
      lib.concatLists
    ];

  mkPathAttrs =
    getValue:
    lib.pipe optionPaths [
      (map (path: lib.setAttrByPath path (getValue path)))
      (lib.foldl' lib.recursiveUpdate { })
    ];

  restoreDefinitionProperties =
    option:
    # Sender evaluation strips these wrappers before exposing definitions.
    map (definition: {
      inherit (definition) file;
      value = lib.mkOverride option.highestPrio (
        if definition ? priority then lib.mkOrder definition.priority definition.value else definition.value
      );
    }) option.definitionsWithLocations;
in
module
