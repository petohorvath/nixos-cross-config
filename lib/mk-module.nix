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
{ lib, ... }:
let
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
    in
    # These wrappers must stay lazy while the module structure is assembled.
    lib.setAttrByPath path (lib.mkMerge definitions);

  collectDefinitions =
    path:
    lib.pipe nodes [
      builtins.attrValues
      (lib.concatMap (node: lib.attrByPath path [ ] (node.config.crossConfig.nodes.${name} or { })))
      (map lib.mkDefinition)
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
{
  options.crossConfig.nodes = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule mkContributionModule);
    default = { };
    description = "Configuration contributions indexed by receiver node identity.";
    apply = lib.mapAttrs (_: contribution: contribution._definitions);
  };

  # The receiving structure depends only on the caller's forwarding surface.
  config = lib.pipe optionPaths [
    (map mkReceivingDefinition)
    lib.mkMerge
  ];
}
