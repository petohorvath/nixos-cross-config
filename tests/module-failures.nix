{ crossConfig, nixpkgs }:
let
  inherit (nixpkgs) lib;
  evaluateModules =
    modules:
    lib.evalModules {
      modules = modules ++ [
        {
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
            description = "Assertions emitted by participating modules.";
          };
        }
      ];
    };
  evaluate =
    settings:
    evaluateModules [
      crossConfig.nixosModules.default
      { crossConfig = settings; }
    ];
  settings = {
    name = "receiver";
    nodeCollection = { };
    optionPaths = [ ];
  };
in
{
  missingName = (evaluate (builtins.removeAttrs settings [ "name" ])).config.assertions;
  missingCollection =
    (evaluate (builtins.removeAttrs settings [ "nodeCollection" ])).config.assertions;
  missingPaths = (evaluate (builtins.removeAttrs settings [ "optionPaths" ])).config.assertions;
  invalidName = (evaluate (settings // { name = 42; })).config.assertions;
  invalidCollection = (evaluate (settings // { nodeCollection = [ ]; })).config.assertions;
  invalidPaths =
    (evaluate (settings // { optionPaths = "inventory.values"; })).config.crossConfig.optionPaths;
  invalidPath =
    (evaluate (settings // { optionPaths = [ "inventory.values" ]; })).config.crossConfig.optionPaths;
  invalidSegment =
    (evaluate (
      settings
      // {
        optionPaths = [
          [
            "inventory"
            42
          ]
        ];
      }
    )).config.crossConfig.optionPaths;
  emptyRegistration =
    (evaluate (settings // { optionPaths = [ [ ] ]; })).config.crossConfig.optionPaths;
  reservedCrossConfig =
    (evaluate (
      settings
      // {
        optionPaths = [
          [
            "crossConfig"
            "nodes"
          ]
        ];
      }
    )).config.crossConfig.optionPaths;
  reservedModule =
    (evaluate (
      settings
      // {
        optionPaths = [
          [
            "_module"
            "args"
          ]
        ];
      }
    )).config.crossConfig.optionPaths;
  reservedWithoutName =
    (evaluate {
      inherit (settings) nodeCollection;
      optionPaths = [ [ "crossConfig" ] ];
    }).config.crossConfig.optionPaths;
  legacyReservedCrossConfig =
    (evaluateModules [
      (crossConfig.lib.mkModule {
        inherit (settings) name;
        nodes = { };
        optionPaths = [
          [
            "crossConfig"
            "nodes"
          ]
        ];
      })
    ]).config.assertions;
  legacyReservedModule =
    (evaluateModules [
      (crossConfig.lib.mkModule {
        inherit (settings) name;
        nodes = { };
        optionPaths = [
          [
            "_module"
            "args"
          ]
        ];
      })
    ]).config.assertions;
  conflictingCollections =
    (evaluateModules [
      crossConfig.nixosModules.default
      { crossConfig = settings; }
      {
        crossConfig.nodeCollection.unused =
          let
            first = second;
            second = first;
          in
          first;
      }
    ]).config.assertions;
}
