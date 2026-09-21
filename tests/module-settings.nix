{ crossConfig, nixpkgs }:
let
  inherit (nixpkgs) lib;
  mkNodes = import ./helpers/mk-module-nodes.nix { inherit crossConfig lib; };
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
        expr = builtins.all (
          node:
          node.config.crossConfig.optionPaths == expectedPaths
          && builtins.all (entry: entry.assertion) node.config.assertions
        ) (builtins.attrValues nodes);
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
        expr = builtins.attrNames node.config.crossConfig.nodeCollection;
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
  nodes = mkNodes {
    optionPaths = [
      [
        "inventory"
        "values"
      ]
    ];
    modules = lib.genAttrs [ "alpha" "beta" ] (name: {
      imports = [
        {
          crossConfig.optionPaths = [
            [
              "inventory"
              "values"
            ]
          ];
        }
      ];
      options.inventory.values = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Values at a repeatedly registered destination.";
      };
      config.crossConfig.nodes.${if name == "alpha" then "beta" else "alpha"}.inventory.values = [ name ];
    });
  };
in
{
  duplicate = {
    testAlphaValues = {
      expr = nodes.alpha.config.inventory.values;
      expected = [ "beta" ];
    };
    testBetaValues = {
      expr = nodes.beta.config.inventory.values;
      expected = [ "alpha" ];
    };
    testNormalizedPaths = {
      expr = nodes.alpha.config.crossConfig.optionPaths;
      expected = [ valuePath ];
    };
    testAssertions = {
      expr = builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions) (
        builtins.attrValues nodes
      );
      expected = true;
    };
  };
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
    { crossConfig.nodeCollection.unused = throw "Unused node was forced."; }
  ];
  collectionPriorities = checkIdleCollection [
    { crossConfig.nodeCollection = lib.mkDefault (throw "Discarded collection was forced."); }
    { crossConfig.nodeCollection.unused = throw "Selected node was forced."; }
  ];
}
