{
  allAssertionsPass,
  constructorArguments,
  evaluateConstructor,
  mkReceiverLib,
  ...
}:
let
  optionPaths = [
    [
      "inventory"
      "values"
    ]
    [
      "inventory"
      "crossConfig"
    ]
    [
      "inventory"
      "_module"
    ]
  ];

  nodes = {
    alpha = mkNode {
      name = "alpha";
      receiver = "beta";
    };
    beta = mkNode {
      name = "beta";
      receiver = "alpha";
    };
  };

  mkNode =
    { name, receiver }:
    evaluateConstructor { inherit name nodes optionPaths; } {
      specialArgs = {
        inherit receiver;
        lib = mkReceiverLib name;
        name = "ordinary-name-${name}";
        nodes.marker = "ordinary-nodes-${name}";
        optionPaths = [ [ "ordinary-optionPaths-${name}" ] ];
      };
      modules = [
        ../fixtures/factory-node.nix
        {
          config = {
            _module.args.ordinaryArgument = "argument-${name}";
            inventory.identity = name;
          };
        }
      ];
    };

  mkNodeTests =
    { name, sender }:
    let
      node = nodes.${name};
      sourcePath = toString ../fixtures/factory-node.nix;
    in
    {
      testConstructorLocation = {
        expr = map (definition: definition.file) node.options.crossConfig.name.definitionsWithLocations;
        expected = [ (toString ../../lib/default.nix) ];
      };
      testDeclarations = {
        expr = node.options.crossConfig.contributions.declarations;
        expected = [ (toString ../../nixos/module.nix) ];
      };
      testReceiverLibrary = {
        expr = node.options.crossConfig.contributions.receiverLibrary;
        expected = name;
      };
      testModuleArguments = {
        expr = node.config.inventory.observedArguments;
        expected = [
          "ordinary-name-${name}"
          "ordinary-nodes-${name}"
          "ordinary-optionPaths-${name}"
          "argument-${name}"
        ];
      };
      testContributions = {
        expr = node.config.inventory.values;
        expected = [
          "from-${sender}-argument-${sender}"
          "local-${name}-argument-${name}"
        ];
      };
      testNestedCrossConfig = {
        expr = node.config.inventory.crossConfig;
        expected = [ "from-${sender}" ];
      };
      testNestedModule = {
        expr = node.config.inventory._module;
        expected = [ "from-${sender}" ];
      };
      testSourceLocations = {
        expr = map (definition: definition.file) node.options.inventory.values.definitionsWithLocations;
        expected = [
          "${sourcePath} (sender `${sender}`, receiver `${name}`, destination `inventory.values`)"
          sourcePath
        ];
      };
      testAssertions = {
        expr = allAssertionsPass { inherit node; };
        expected = true;
      };
    };
in
{
  testConstructorArguments = {
    expr = constructorArguments;
    expected = {
      name = false;
      nodes = false;
      optionPaths = false;
    };
  };
  alpha = mkNodeTests {
    name = "alpha";
    sender = "beta";
  };
  beta = mkNodeTests {
    name = "beta";
    sender = "alpha";
  };
}
