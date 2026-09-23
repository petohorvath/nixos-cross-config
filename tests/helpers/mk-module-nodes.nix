{ evaluateModule, lib }:
{ optionPaths, modules }:
let
  nodes = lib.mapAttrs (
    name: module:
    evaluateModule {
      modules = [
        {
          config.crossConfig = {
            inherit name optionPaths;
            nodeConfigurations = nodes;
          };
        }
        module
      ];
    }
  ) modules;
in
nodes
