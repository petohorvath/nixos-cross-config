{
  constructorArguments,
  evaluateConstructor,
  lib,
  ...
}:
let
  result = {
    testConstructorArguments = {
      expr = constructorArguments;
      expected = {
        name = false;
        nodes = false;
        optionPaths = false;
      };
    };
    alpha = checkNode "alpha" "beta";
    beta = checkNode "beta" "alpha";
  };

  checkNode =
    name: sender:
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
        expr = node.options.crossConfig.nodes.declarations;
        expected = [ (toString ../../nixos/module.nix) ];
      };
      testReceiverLibrary = {
        expr = node.options.crossConfig.nodes.receiverLibrary;
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
          (lib.concatStrings [
            "${sourcePath} (sender `${sender}`, receiver `${name}`, "
            "destination `inventory.values`)"
          ])
          sourcePath
        ];
      };
      testAssertions = {
        expr = builtins.all (entry: entry.assertion) node.config.assertions;
        expected = true;
      };
    };

  nodes = {
    alpha = mkNode "alpha" "beta";
    beta = mkNode "beta" "alpha";
  };

  mkNode =
    name: receiver:
    evaluateConstructor { inherit name nodes optionPaths; } {
      specialArgs = {
        inherit receiver;
        lib = lib // {
          mkOption = arguments: lib.mkOption arguments // { receiverLibrary = name; };
        };
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
in
result
