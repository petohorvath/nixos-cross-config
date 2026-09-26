{ evaluateConstructor, evaluateModule }:
let
  evaluate = settings: evaluateModule { modules = [ { crossConfig = settings; } ]; };
  settings = {
    name = "receiver";
    nodeConfigurations = { };
    optionPaths = [ ];
  };
  evaluatePaths =
    value: (evaluate (settings // { optionPaths = value; })).config.crossConfig.optionPaths;
in
{
  missingName = (evaluate (removeAttrs settings [ "name" ])).config.assertions;
  missingCollection = (evaluate (removeAttrs settings [ "nodeConfigurations" ])).config.assertions;
  missingPaths = (evaluate (removeAttrs settings [ "optionPaths" ])).config.assertions;
  invalidName = (evaluate (settings // { name = 42; })).config.assertions;
  invalidCollection = (evaluate (settings // { nodeConfigurations = [ ]; })).config.assertions;
  oldCollectionName = (evaluate (settings // { nodeCollection = { }; })).config.assertions;
  oldContributionsName = (evaluate (settings // { nodes = { }; })).config.assertions;
  invalidPaths = evaluatePaths "inventory.values";
  invalidPath = evaluatePaths [ "inventory.values" ];
  invalidSegment = evaluatePaths [
    [
      "inventory"
      42
    ]
  ];
  emptyRegistration = evaluatePaths [ [ ] ];
  reservedCrossConfig = evaluatePaths [
    [
      "crossConfig"
      "contributions"
    ]
  ];
  reservedModule = evaluatePaths [
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
          "contributions"
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
