{
  lib,
  name,
  optionPaths,
}:
let
  getDefinitions =
    receiver: contribution:
    builtins.addErrorContext "while evaluating contributions from sender `${name}` to receiver `${receiver}`:" contribution._definitions;

  mkContributionModule =
    { options, ... }:
    {
      options = mkPathAttrs mkContributionOption // {
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

  mkContributionOption =
    path:
    lib.mkOption {
      type = lib.types.raw;
      description = "Definitions contributed to ${lib.showOption path}.";
    };

  mkPathAttrs =
    getValue:
    lib.pipe optionPaths [
      (map (path: lib.setAttrByPath path (getValue path)))
      (lib.foldl' lib.recursiveUpdate { })
    ];

  restoreDefinitionProperties = import ./restore-definition-properties.nix { inherit lib; };
in
lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule mkContributionModule);
  default = { };
  description = "Configuration contributions indexed by receiver node identity.";
  apply = lib.mapAttrs getDefinitions;
}
