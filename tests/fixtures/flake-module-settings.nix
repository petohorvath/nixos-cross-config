{ crossConfig, flakeParts }:
let
  evaluate =
    modules:
    (flakeParts.lib.evalFlakeModule { inputs.self.outPath = ../..; } {
      imports = [ crossConfig.flakeModules.default ] ++ modules;
      systems = [ ];
    }).config.crossConfig;
  paths = value: (evaluate [ { crossConfig.optionPaths = value; } ]).optionPaths;
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
  flakeInvalidPaths = paths "inventory.values";
  flakeInvalidPath = paths [ "inventory.values" ];
  flakeInvalidSegment = paths [
    [
      "inventory"
      42
    ]
  ];
  flakeEmptyRegistration = paths [ [ ] ];
  flakeReservedCrossConfig = paths [
    [
      "crossConfig"
      "nodes"
    ]
  ];
  flakeReservedModule = paths [
    [
      "_module"
      "args"
    ]
  ];
}
