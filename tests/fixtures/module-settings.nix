{ evaluateModule, evaluateConstructor }:
let
  evaluate = settings: evaluateModule { modules = [ { crossConfig = settings; } ]; };
  settings = {
    name = "receiver";
    nodeConfigurations = { };
    optionPaths = [ ];
  };
  paths = value: (evaluate (settings // { optionPaths = value; })).config.crossConfig.optionPaths;
in
{
  missingName = (evaluate (removeAttrs settings [ "name" ])).config.assertions;
  missingCollection = (evaluate (removeAttrs settings [ "nodeConfigurations" ])).config.assertions;
  missingPaths = (evaluate (removeAttrs settings [ "optionPaths" ])).config.assertions;
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
    (evaluateConstructor {
      inherit (settings) name;
      nodes = { };
      optionPaths = [
        [
          "crossConfig"
          "nodes"
        ]
      ];
    } { modules = [ ]; }).config.assertions;
  legacyReservedModule =
    (evaluateConstructor {
      inherit (settings) name;
      nodes = { };
      optionPaths = [
        [
          "_module"
          "args"
        ]
      ];
    } { modules = [ ]; }).config.assertions;
  conflictingCollections =
    (evaluateModule {
      modules = [
        { crossConfig = settings; }
        {
          crossConfig.nodeConfigurations.unused =
            let
              first = second;
              second = first;
            in
            first;
        }
      ];
    }).config.assertions;
}
