{
  checkAssertions,
  crossConfig,
  messagePattern,
  nixpkgs,
  ...
}:
let
  rejections = import ../fixtures/module-settings.nix { inherit crossConfig nixpkgs; };
  inherit (nixpkgs) lib;
  mkNodes = import ../helpers/mk-module-nodes.nix { inherit crossConfig lib; };
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
      nodes = mkNodes {
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
                description = "Values delivered through composed registrations.";
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
      node = lib.evalModules {
        modules = modules ++ [
          crossConfig.nixosModules.default
          {
            options.assertions = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
              description = "Assertions emitted by participating modules.";
            };
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
    expr = rejections.oldCollectionName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeCollection"
        "does not exist"
      ];
    };
  };

  testRejectsMissingName = {
    expr = rejections.missingName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.name"
        "was accessed but has no value defined"
      ];
    };
  };
  testRejectsMissingCollection = {
    expr = rejections.missingCollection;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "was accessed but has no value defined"
      ];
    };
  };
  testRejectsMissingPaths = {
    expr = rejections.missingPaths;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "was accessed but has no value defined"
      ];
    };
  };
  testRejectsInvalidName = {
    expr = rejections.invalidName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.name"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidCollection = {
    expr = rejections.invalidCollection;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidPaths = {
    expr = rejections.invalidPaths;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidPath = {
    expr = rejections.invalidPath;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidSegment = {
    expr = rejections.invalidSegment;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsEmptyRegistration = {
    expr = rejections.emptyRegistration;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsReservedCrossConfig = {
    expr = rejections.reservedCrossConfig;
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
    expr = rejections.reservedModule;
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
    expr = rejections.reservedWithoutName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "reserved root"
      ];
    };
  };
  testRejectsLegacyReservedCrossConfig = {
    expr = rejections.legacyReservedCrossConfig;
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
    expr = rejections.legacyReservedModule;
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
    expr = rejections.conflictingCollections;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "multiple times"
      ];
    };
  };
}
