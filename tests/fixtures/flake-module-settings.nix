{ evaluateConsumer }:
let
  evaluate = modules: (evaluateConsumer { imports = modules; }).config.crossConfig;
  evaluatePaths = value: (evaluate [ { crossConfig.optionPaths = value; } ]).optionPaths;
in
{
  missingPaths = (evaluate [ ]).optionPaths;
  invalidCollection = (evaluate [ { crossConfig.nodeConfigurations = [ ]; } ]).nodeConfigurations;
  oldCollectionName = (evaluate [ { crossConfig.nodeCollection = { }; } ]).nodeConfigurations;
  conflictingCollections =
    (evaluate [
      { crossConfig.nodeConfigurations = { }; }
      { crossConfig.nodeConfigurations.unused = throw "Conflicting collection entries must stay lazy."; }
    ]).nodeConfigurations;
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
}
