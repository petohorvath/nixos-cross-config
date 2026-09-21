{ crossConfig, lib }:
{ optionPaths, modules }:
let
  nodes = lib.mapAttrs (
    name: module:
    lib.evalModules {
      modules = [
        crossConfig.nixosModules.default
        {
          config.crossConfig = {
            inherit name optionPaths;
            nodeCollection = nodes;
          };
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
            description = "Assertions emitted by the forwarding module.";
          };
        }
        module
      ];
    }
  ) modules;
in
nodes
