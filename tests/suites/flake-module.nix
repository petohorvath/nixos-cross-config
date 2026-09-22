{
  checkAssertions,
  crossConfig,
  flakeParts,
  messagePattern,
  nixpkgs,
  system,
}:
let
  rejections = import ../fixtures/flake-module-settings.nix { inherit crossConfig flakeParts; };
  inherit (nixpkgs) lib;
  valuePath = [
    "inventory"
    "values"
  ];
  literalPath = [
    "inventory"
    "literal.values"
  ];
  mkConsumer =
    sharedModules: nodeModule:
    flakeParts.lib.mkFlake { inputs.self.outPath = ../../.; } (
      { config, ... }:
      {
        imports = [ crossConfig.flakeModules.default ] ++ sharedModules;
        systems = [ ];
        flake.nixosConfigurations = lib.genAttrs [ "alpha" "beta" ] (
          name: mkNode config.flake.nixosModules.crossConfig name nodeModule
        );
      }
    );
  mkNode =
    configuredModule: name: nodeModule:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs.lib = lib // {
        mkOption = arguments: lib.mkOption arguments // { receiverLibrary = name; };
      };
      modules = [
        configuredModule
        {
          options.inventory = lib.genAttrs [ "values" "literal.values" ] (
            _:
            lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Received and local inventory values.";
            }
          );
          config = {
            boot.isContainer = true;
            system.stateVersion = "26.05";
            networking.hostName = "${name}-container";
            crossConfig.name = name;
            inventory.values = [ "local-${name}" ];
          };
        }
        nodeModule
      ];
    };
  reciprocal = { config, lib, ... }: {
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
        expr = builtins.all (node: node.config.crossConfig.optionPaths == paths) (
          builtins.attrValues nodes
        );
        expected = true;
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };
  defaultConsumer = mkConsumer [ { crossConfig.optionPaths = [ valuePath ]; } ] reciprocal;
  mergedConsumer =
    mkConsumer
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
        imports = [ reciprocal ];
        crossConfig.nodes.alpha.inventory."literal.values" = [ "literal" ];
      };
  emptyConsumer = mkConsumer [
    {
      crossConfig = {
        optionPaths = [ ];
        nodeConfigurations.unused = throw "An unused node in the opaque collection was forced.";
      };
    }
  ] { };
  overriddenConsumer =
    mkConsumer
      [
        {
          crossConfig = {
            optionPaths = [ literalPath ];
            nodeConfigurations = throw "The overridden flake-level collection was forced.";
          };
        }
      ]
      {
        imports = [ reciprocal ];
        crossConfig = {
          optionPaths = [ valuePath ];
          nodeConfigurations = overriddenConsumer.nixosConfigurations;
        };
      };
  explicitConsumer = flakeParts.lib.mkFlake { inputs.self.outPath = ../../.; } (
    { config, ... }:
    let
      nodes = {
        alpha = mkNode config.flake.nixosModules.crossConfig "alpha" {
          crossConfig.nodes.guest.inventory.values = lib.mkBefore [ "from-alpha" ];
        };
        guest = mkNode config.flake.nixosModules.crossConfig "guest" {
          crossConfig.nodes.alpha.inventory.values = lib.mkBefore [ "from-guest" ];
        };
      };
    in
    {
      imports = [ crossConfig.flakeModules.default ];
      systems = [ ];
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
      consumer = import ../../examples/flake-parts.nix {
        inherit
          crossConfig
          flakeParts
          nixpkgs
          system
          ;
      };
      nodes = consumer.nixosConfigurations;
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
        expr = checkAssertions nodes;
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
      evaluation = flakeParts.lib.evalFlakeModule { inputs.self.outPath = ../../.; } {
        imports = [
          crossConfig.flakeModules.default
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
        systems = [ ];
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
      consumer = flakeParts.lib.mkFlake { inputs.self.outPath = ../../.; } {
        imports = [ crossConfig.flakeModules.default ];
        systems = [ ];
        crossConfig.optionPaths = [ ];
        flake.nixosConfigurations.untouched = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            {
              boot.isContainer = true;
              system.stateVersion = "26.05";
            }
          ];
        };
      };
    in
    {
      testExplicitImport = {
        expr = consumer.nixosConfigurations.untouched.options ? crossConfig;
        expected = false;
      };
      testAssertions = {
        expr = checkAssertions consumer.nixosConfigurations;
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
        expr = checkAssertions nodes;
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
      expr = checkAssertions emptyConsumer.nixosConfigurations;
      expected = true;
    };
  };
  sharedDefaults = checkPair (mkConsumer [
    { crossConfig.optionPaths = lib.mkDefault (throw "Overridden default registrations were forced."); }
    { crossConfig.optionPaths = [ valuePath ]; }
  ] reciprocal) [ valuePath ];
  sharedForce = checkPair (mkConsumer [
    { crossConfig.optionPaths = [ [ "crossConfig" ] ]; }
    { crossConfig.optionPaths = lib.mkForce [ valuePath ]; }
  ] reciprocal) [ valuePath ];
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
      consumer = flakeParts.lib.mkFlake { inputs.self.outPath = ../../.; } {
        imports = [ ../../flake-module.nix ];
        systems = [ ];
        crossConfig.optionPaths = [ ];
      };
      node = mkNode consumer.nixosModules.crossConfig "idle" { };
    in
    {
      testPlainConstructor = {
        expr = builtins.isFunction (import ../../lib).mkModule;
        expected = true;
      };
      testPlainModule = {
        expr = builtins.isFunction (import ../../nixos/module.nix);
        expected = true;
      };
      testEmptyPaths = {
        expr = node.config.crossConfig.optionPaths;
        expected = [ ];
      };
      testAssertions = {
        expr = builtins.all (entry: entry.assertion) node.config.assertions;
        expected = true;
      };
    };
}
// {
  testRejectsOldCollectionName = {
    expr = rejections.flakeOldCollectionName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeCollection"
        "does not exist"
      ];
    };
  };

  testRejectsConflictingCollections = {
    expr = rejections.flakeConflictingCollections;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "multiple times"
      ];
    };
  };
  testRejectsEmptyRegistration = {
    expr = rejections.flakeEmptyRegistration;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidCollection = {
    expr = rejections.flakeInvalidCollection;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.nodeConfigurations"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidPath = {
    expr = rejections.flakeInvalidPath;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidPaths = {
    expr = rejections.flakeInvalidPaths;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsInvalidSegment = {
    expr = rejections.flakeInvalidSegment;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "is not of type"
      ];
    };
  };
  testRejectsMissingPaths = {
    expr = rejections.flakeMissingPaths;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "crossConfig.optionPaths"
        "was accessed but has no value defined"
      ];
    };
  };
  testRejectsReservedCrossConfig = {
    expr = rejections.flakeReservedCrossConfig;
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
    expr = rejections.flakeReservedModule;
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
