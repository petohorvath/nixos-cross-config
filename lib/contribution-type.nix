{ lib, optionPaths }:
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

  mkPathAttrs =
    getValue:
    lib.pipe optionPaths [
      (map (path: lib.setAttrByPath path (getValue path)))
      (lib.foldl' lib.recursiveUpdate { })
    ];

  restoreDefinitionProperties = import ./restore-definition-properties.nix { inherit lib; };
in
lib.types.submodule mkContributionModule
