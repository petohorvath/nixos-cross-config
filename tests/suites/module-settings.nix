{
  checkAssertions,
  evaluateModule,
  lib,
  messagePattern,
  mkModuleNodes,
  moduleRejections,
  ...
}:
let
  valuePath = [
    "inventory"
    "values"
  ];
  otherPath = [
    "inventory"
    "other"
  ];
  checkRegistrations =
    {
      modules,
      expectedPaths,
      outgoing ? {
        values = [ "delivered" ];
      },
      expectedOther ? [ ],
    }:
    let
      nodes = mkModuleNodes {
        optionPaths = lib.mkDefault [ ];
        modules = {
          sender = {
            imports = modules;
            crossConfig.nodes.receiver.inventory = outgoing;
          };
          receiver = {
            imports = modules;
            options.inventory = lib.genAttrs [ "values" "other" ] (
              _:
              lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Values delivered through composed registrations.
                '';
              }
            );
          };
        };
      };
    in
    {
      testValues = {
        expr = nodes.receiver.config.inventory.values;
        expected = [ "delivered" ];
      };
      testOtherValues = {
        expr = nodes.receiver.config.inventory.other;
        expected = expectedOther;
      };
      testRegistrations = {
        expr = lib.mapAttrs (_: node: node.config.crossConfig.optionPaths) nodes;
        expected = {
          sender = expectedPaths;
          receiver = expectedPaths;
        };
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };
  checkIdleCollection =
    modules:
    let
      node = evaluateModule {
        modules = modules ++ [
          {
            config.crossConfig = {
              name = "idle";
              optionPaths = [ ];
            };
          }
        ];
      };
    in
    {
      testCollectionNames = {
        expr = builtins.attrNames node.config.crossConfig.nodeConfigurations;
        expected = [ "unused" ];
      };
      testEmptyPaths = {
        expr = node.config.crossConfig.optionPaths;
        expected = [ ];
      };
      testEmptyContributions = {
        expr = node.config.crossConfig.nodes;
        expected = { };
      };
      testAssertions = {
        expr = builtins.all (entry: entry.assertion) node.config.assertions;
        expected = true;
      };
    };
in
{
  splitRegistrations = checkRegistrations {
    modules = [
      {
        crossConfig.optionPaths = lib.mkBefore [
          valuePath
          otherPath
        ];
      }
      {
        crossConfig.optionPaths = lib.mkAfter [
          otherPath
          valuePath
        ];
      }
    ];
    expectedPaths = [
      valuePath
      otherPath
    ];
    outgoing = {
      values = [ "delivered" ];
      other = [ "another destination" ];
    };
    expectedOther = [ "another destination" ];
  };
  defaultRegistrations = checkRegistrations {
    modules = [ { crossConfig.optionPaths = lib.mkDefault [ valuePath ]; } ];
    expectedPaths = [ valuePath ];
  };
  ordinaryRegistrations = checkRegistrations {
    modules = [
      { crossConfig.optionPaths = lib.mkDefault (throw "Discarded default registrations were forced."); }
      { crossConfig.optionPaths = [ valuePath ]; }
    ];
    expectedPaths = [ valuePath ];
  };
  forcedRegistrations = checkRegistrations {
    modules = [
      { crossConfig.optionPaths = [ [ "crossConfig" ] ]; }
      { crossConfig.optionPaths = lib.mkForce [ valuePath ]; }
    ];
    expectedPaths = [ valuePath ];
  };
  independentCondition = checkRegistrations {
    modules = [
      ({ config, ... }: {
        options.crossConfig.registerValues = lib.mkEnableOption "the inventory destination";
        config = {
          crossConfig.registerValues = true;
          crossConfig.optionPaths = lib.mkMerge [
            (lib.mkIf config.crossConfig.registerValues [ valuePath ])
            (lib.mkIf (!config.crossConfig.registerValues) (throw "Disabled registrations were forced."))
          ];
        };
      })
    ];
    expectedPaths = [ valuePath ];
  };
  opaqueCollection = checkIdleCollection [
    { crossConfig.nodeConfigurations.unused = throw "Unused node was forced."; }
  ];
  collectionPriorities = checkIdleCollection [
    { crossConfig.nodeConfigurations = lib.mkDefault (throw "Discarded collection was forced."); }
    { crossConfig.nodeConfigurations.unused = throw "Selected node was forced."; }
  ];
  forcedCollection = checkIdleCollection [
    {
      crossConfig.nodeConfigurations.discarded = throw "Discarded ordinary collection entry was forced.";
    }
    {
      crossConfig.nodeConfigurations = lib.mkForce {
        unused = throw "Selected node was forced.";
      };
    }
  ];
  testRejectsOldCollectionName = {
    expr = moduleRejections.oldCollectionName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeCollection"
        "does not exist"
      ];
    };
  };
  testRejectsMissingName = {
    expr = moduleRejections.missingName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.name"
        "was accessed but has no value defined"
      ];
    };
  };
  testRejectsMissingCollection = {
    expr = moduleRejections.missingCollection;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "was accessed but has no value defined"
      ];
    };
  };
  testRejectsMissingPaths = {
    expr = moduleRejections.missingPaths;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "was accessed but has no value defined"
      ];
    };
  };
  testRejectsInvalidName = {
    expr = moduleRejections.invalidName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.name"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidCollection = {
    expr = moduleRejections.invalidCollection;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidPaths = {
    expr = moduleRejections.invalidPaths;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidPath = {
    expr = moduleRejections.invalidPath;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidSegment = {
    expr = moduleRejections.invalidSegment;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsEmptyRegistration = {
    expr = moduleRejections.emptyRegistration;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsReservedCrossConfig = {
    expr = moduleRejections.reservedCrossConfig;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "reserved root"
        "crossConfig.nodes"
        "receiver"
      ];
    };
  };
  testRejectsReservedModule = {
    expr = moduleRejections.reservedModule;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "reserved root"
        "_module.args"
        "receiver"
      ];
    };
  };
  testRejectsReservedWithoutName = {
    expr = moduleRejections.reservedWithoutName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "reserved root"
      ];
    };
  };
  testRejectsLegacyReservedCrossConfig = {
    expr = moduleRejections.legacyReservedCrossConfig;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "reserved root"
        "crossConfig.nodes"
        "receiver"
      ];
    };
  };
  testRejectsLegacyReservedModule = {
    expr = moduleRejections.legacyReservedModule;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "reserved root"
        "_module.args"
        "receiver"
      ];
    };
  };
  testRejectsConflictingCollections = {
    expr = moduleRejections.conflictingCollections;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "multiple times"
      ];
    };
  };
}
