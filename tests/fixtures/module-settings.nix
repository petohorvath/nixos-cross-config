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
    nodeConfigurations = { };
    optionPaths = [ ];
  };
  paths = value: (evaluate (settings // { optionPaths = value; })).config.crossConfig.optionPaths;
in
{
  missingName = (evaluate (builtins.removeAttrs settings [ "name" ])).config.assertions;
  missingCollection =
    (evaluate (builtins.removeAttrs settings [ "nodeConfigurations" ])).config.assertions;
  missingPaths = (evaluate (builtins.removeAttrs settings [ "optionPaths" ])).config.assertions;
  invalidName = (evaluate (settings // { name = 42; })).config.assertions;
  invalidCollection = (evaluate (settings // { nodeConfigurations = [ ]; })).config.assertions;
  oldCollectionName = (evaluate (settings // { nodeCollection = { }; })).config.assertions;
  invalidPaths = paths "inventory.values";
  invalidPath = paths [ "inventory.values" ];
  invalidSegment = paths [
    [
      "inventory"
      42
    ]
  ];
  emptyRegistration = paths [ [ ] ];
  reservedCrossConfig = paths [
    [
      "crossConfig"
      "nodes"
    ]
  ];
  reservedModule = paths [
    [
      "_module"
      "args"
    ]
  ];
  reservedWithoutName =
    (evaluate {
      inherit (settings) nodeConfigurations;
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
        crossConfig.nodeConfigurations.unused =
          let
            first = second;
            second = first;
          in
          first;
      }
    ]).config.assertions;
}
