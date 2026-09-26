{
  allAssertionsPass,
  flakeConsumer,
  flakeExample,
  flakeRejections,
  lib,
  messagePattern,
  plainFlakeConsumer,
  ...
}:
let
  inherit (flakeConsumer)
    evaluateConsumer
    mkConsumer
    mkNode
    mkPairConsumer
    mkUnconfiguredNode
    ;
  valuePath = [
    "inventory"
    "values"
  ];
  literalPath = [
    "inventory"
    "literal.values"
  ];
  reciprocalModule = { config, lib, ... }: {
    crossConfig.nodes.${
      if config.crossConfig.name == "alpha" then "beta" else "alpha"
    }.inventory.values =
      lib.mkBefore [ "from-${config.crossConfig.name}" ];
  };
  checkPair =
    consumer: paths:
    let
      nodes = consumer.nixosConfigurations;
    in
    {
      testAlphaValues = {
        expr = nodes.alpha.config.inventory.values;
        expected = [
          "from-beta"
          "local-alpha"
        ];
      };
      testBetaValues = {
        expr = nodes.beta.config.inventory.values;
        expected = [
          "from-alpha"
          "local-beta"
        ];
      };
      testRegistrations = {
        expr = lib.mapAttrs (_: node: node.config.crossConfig.optionPaths) nodes;
        expected = {
          alpha = paths;
          beta = paths;
        };
      };
      testAssertions = {
        expr = allAssertionsPass nodes;
        expected = true;
      };
    };
  defaultConsumer = mkPairConsumer [ { crossConfig.optionPaths = [ valuePath ]; } ] reciprocalModule;
  mergedConsumer =
    mkPairConsumer
      [
        {
          crossConfig.optionPaths = lib.mkBefore [
            valuePath
            literalPath
          ];
        }
        {
          crossConfig.optionPaths = lib.mkAfter [
            literalPath
            valuePath
          ];
        }
      ]
      {
        imports = [ reciprocalModule ];
        crossConfig.nodes.alpha.inventory."literal.values" = [ "literal" ];
      };
  emptyConsumer = mkPairConsumer [
    {
      crossConfig = {
        optionPaths = [ ];
        nodeConfigurations.unused = throw "An unused node in the opaque collection was forced.";
      };
    }
  ] { };
  overriddenConsumer =
    mkPairConsumer
      [
        {
          crossConfig = {
            optionPaths = [ literalPath ];
            nodeConfigurations = throw "The overridden flake-level collection was forced.";
          };
        }
      ]
      {
        imports = [ reciprocalModule ];
        crossConfig = {
          optionPaths = [ valuePath ];
          nodeConfigurations = overriddenConsumer.nixosConfigurations;
        };
      };
  explicitConsumer = mkConsumer (
    { config, ... }:
    let
      nodes = {
        alpha = mkNode {
          configuredModule = config.flake.nixosModules.crossConfig;
          name = "alpha";
          nodeModule.crossConfig.nodes.guest.inventory.values = lib.mkBefore [ "from-alpha" ];
        };
        guest = mkNode {
          configuredModule = config.flake.nixosModules.crossConfig;
          name = "guest";
          nodeModule.crossConfig.nodes.alpha.inventory.values = lib.mkBefore [ "from-guest" ];
        };
      };
    in
    {
      crossConfig = {
        nodeConfigurations = nodes;
        optionPaths = [ valuePath ];
      };
      flake = {
        inherit (nodes) guest;
        nixosConfigurations = {
          inherit (nodes) alpha;
          unrelated = throw "A node outside the selected collection was forced.";
        };
      };
    }
  );
in
{
  example =
    let
      nodes = flakeExample.nixosConfigurations;
      virtualHost = nodes.proxy.config.services.nginx.virtualHosts."app.example";
    in
    {
      testProxyPass = {
        expr = virtualHost.locations."/".proxyPass;
        expected = "http://192.0.2.10:8080";
      };
      testAliases = {
        expr = virtualHost.serverAliases;
        expected = [ "www.app.example" ];
      };
      testAssertions = {
        expr = allAssertionsPass nodes;
        expected = true;
      };
    };
  defaultCollection = checkPair defaultConsumer [ valuePath ];
  systemEvaluation = {
    testSystemEvaluation = {
      expr = builtins.all (node: builtins.isString node.config.system.build.toplevel.drvPath) (
        builtins.attrValues defaultConsumer.nixosConfigurations
      );
      expected = true;
    };
  };
  mergedRegistrations =
    (checkPair mergedConsumer [
      valuePath
      literalPath
    ])
    // {
      testLiteralValues = {
        expr = mergedConsumer.nixosConfigurations.alpha.config.inventory."literal.values";
        expected = [
          "literal"
          "literal"
        ];
      };
    };
  sharedRegistrations =
    let
      evaluation = evaluateConsumer {
        imports = [
          {
            crossConfig.optionPaths = lib.mkBefore [
              valuePath
              literalPath
            ];
          }
          {
            crossConfig.optionPaths = lib.mkAfter [
              literalPath
              valuePath
              [
                "inventory"
                "_module"
              ]
              [
                "inventory"
                "crossConfig"
              ]
            ];
          }
        ];
      };
    in
    {
      testRegistrations = {
        expr = evaluation.config.crossConfig.optionPaths;
        expected = [
          valuePath
          literalPath
          [
            "inventory"
            "_module"
          ]
          [
            "inventory"
            "crossConfig"
          ]
        ];
      };
    };
  explicitImports =
    let
      consumer = mkConsumer {
        crossConfig.optionPaths = [ ];
        flake.nixosConfigurations.untouched = mkUnconfiguredNode [
          {
            boot.isContainer = true;
            system.stateVersion = "26.05";
          }
        ];
      };
    in
    {
      testNoImplicitImport = {
        expr = consumer.nixosConfigurations.untouched.options ? crossConfig;
        expected = false;
      };
      testAssertions = {
        expr = allAssertionsPass consumer.nixosConfigurations;
        expected = true;
      };
    };
  explicitCollection =
    let
      nodes = {
        inherit (explicitConsumer.nixosConfigurations) alpha;
        inherit (explicitConsumer) guest;
      };
    in
    {
      testGuestOutsideConfigurations = {
        expr = explicitConsumer.nixosConfigurations ? guest;
        expected = false;
      };
      testAlphaValues = {
        expr = nodes.alpha.config.inventory.values;
        expected = [
          "from-guest"
          "local-alpha"
        ];
      };
      testGuestValues = {
        expr = nodes.guest.config.inventory.values;
        expected = [
          "from-alpha"
          "local-guest"
        ];
      };
      testAssertions = {
        expr = allAssertionsPass nodes;
        expected = true;
      };
    };
  emptyRegistrations = {
    testEmptyRegistrations = {
      expr = builtins.all (
        node:
        node.config.crossConfig.optionPaths == [ ]
        && node.config.crossConfig.nodes == { }
        && builtins.attrNames node.config.crossConfig.nodeConfigurations == [ "unused" ]
      ) (builtins.attrValues emptyConsumer.nixosConfigurations);
      expected = true;
    };
    testAssertions = {
      expr = allAssertionsPass emptyConsumer.nixosConfigurations;
      expected = true;
    };
  };
  sharedDefaults = checkPair (mkPairConsumer [
    { crossConfig.optionPaths = lib.mkDefault (throw "Overridden default registrations were forced."); }
    { crossConfig.optionPaths = [ valuePath ]; }
  ] reciprocalModule) [ valuePath ];
  sharedForce = checkPair (mkPairConsumer [
    { crossConfig.optionPaths = [ [ "crossConfig" ] ]; }
    { crossConfig.optionPaths = lib.mkForce [ valuePath ]; }
  ] reciprocalModule) [ valuePath ];
  nodeDefaults = checkPair overriddenConsumer [ valuePath ];
  receiverLibrary = {
    testReceiverLibrary = {
      expr =
        builtins.all
          (
            name:
            defaultConsumer.nixosConfigurations.${name}.options.crossConfig.nodes.receiverLibrary == name
            &&
              defaultConsumer.nixosConfigurations.${name}.options.crossConfig.optionPaths.receiverLibrary == name
          )
          [
            "alpha"
            "beta"
          ];
      expected = true;
    };
  };
  plainImport =
    let
      consumer = plainFlakeConsumer.mkConsumer {
        crossConfig.optionPaths = [ ];
      };
      node = mkNode {
        configuredModule = consumer.nixosModules.crossConfig;
        name = "idle";
        nodeModule = { };
      };
    in
    {
      testEmptyPaths = {
        expr = node.config.crossConfig.optionPaths;
        expected = [ ];
      };
      testAssertions = {
        expr = allAssertionsPass { inherit node; };
        expected = true;
      };
    };
  testRejectsOldCollectionName = {
    expr = flakeRejections.oldCollectionName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeCollection"
        "does not exist"
      ];
    };
  };
  testRejectsConflictingCollections = {
    expr = flakeRejections.conflictingCollections;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "multiple times"
      ];
    };
  };
  testRejectsEmptyRegistration = {
    expr = flakeRejections.emptyRegistration;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidCollection = {
    expr = flakeRejections.invalidCollection;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidPath = {
    expr = flakeRejections.invalidPath;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidPaths = {
    expr = flakeRejections.invalidPaths;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidSegment = {
    expr = flakeRejections.invalidSegment;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsMissingPaths = {
    expr = flakeRejections.missingPaths;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "was accessed but has no value defined"
      ];
    };
  };
  testRejectsReservedCrossConfig = {
    expr = flakeRejections.reservedCrossConfig;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "reserved root"
        "crossConfig.nodes"
      ];
    };
  };
  testRejectsReservedModule = {
    expr = flakeRejections.reservedModule;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "reserved root"
        "_module.args"
      ];
    };
  };
}
