{
  crossConfig,
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) allAssertionsPass mkNodeCollection mkReceiverLib;
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

  receivers = {
    alpha = "beta";
    beta = "alpha";
  };

  nodes = mkNodeCollection {
    evaluator = "modules";
    adapter = "compatibility";
    inherit optionPaths;
    specialArgs = name: {
      lib = mkReceiverLib name;
      name = "ordinary-name-${name}";
      nodes.marker = "ordinary-nodes-${name}";
      optionPaths = [ [ "ordinary-optionPaths-${name}" ] ];
      receiver = receivers.${name};
    };
    modules = lib.mapAttrs (name: _: {
      imports = [ ../fixtures/factory-node.nix ];
      config = {
        _module.args.ordinaryArgument = "argument-${name}";
        inventory.identity = name;
      };
    }) receivers;
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
    expr = builtins.functionArgs crossConfig.lib.mkModule;
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
