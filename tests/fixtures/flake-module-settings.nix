{ evaluateConsumer }:
let
  evaluate = modules: (evaluateConsumer { imports = modules; }).config.crossConfig;
  evaluatePaths = value: (evaluate [ { crossConfig.optionPaths = value; } ]).optionPaths;
in
{
  flakeMissingPaths = (evaluate [ ]).optionPaths;
  flakeInvalidCollection =
    (evaluate [ { crossConfig.nodeConfigurations = [ ]; } ]).nodeConfigurations;
  flakeOldCollectionName = (evaluate [ { crossConfig.nodeCollection = { }; } ]).nodeConfigurations;
  flakeConflictingCollections =
    (evaluate [
      { crossConfig.nodeConfigurations = { }; }
      { crossConfig.nodeConfigurations.unused = throw "Conflicting collection entries must stay lazy."; }
    ]).nodeConfigurations;
  flakeInvalidPaths = evaluatePaths "inventory.values";
  flakeInvalidPath = evaluatePaths [ "inventory.values" ];
  flakeInvalidSegment = evaluatePaths [
    [
      "inventory"
      42
    ]
  ];
  flakeEmptyRegistration = evaluatePaths [ [ ] ];
  flakeReservedCrossConfig = evaluatePaths [
    [
      "crossConfig"
      "nodes"
    ]
  ];
  flakeReservedModule = evaluatePaths [
    [
      "_module"
      "args"
    ]
  ];
}
