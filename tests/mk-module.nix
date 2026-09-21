{ nixpkgs }:
let
  inherit (nixpkgs) lib;
  crossConfig = (import ../flake.nix).outputs { };
  result =
    assert builtins.isFunction ((import ../flake.nix).outputs { }).lib.mkModule;
    assert
      builtins.functionArgs crossConfig.lib.mkModule == {
        name = false;
        nodes = false;
        optionPaths = false;
      };
    assert checkNode "alpha" "beta";
    assert checkNode "beta" "alpha";
    true;

  checkNode =
    name: sender:
    let
      node = nodes.${name};
      sourcePath = toString ./fixtures/factory-node.nix;
    in
    assert node.options.crossConfig.nodes.declarations == [ (toString ../lib/module.nix) ];
    assert node.options.crossConfig.nodes.receiverLibrary == name;
    assert
      node.config.inventory.observedArguments == [
        "ordinary-name-${name}"
        "ordinary-nodes-${name}"
        "ordinary-optionPaths-${name}"
        "argument-${name}"
      ];
    assert
      node.config.inventory.values == [
        "from-${sender}-argument-${sender}"
        "local-${name}-argument-${name}"
      ];
    assert node.config.inventory.crossConfig == [ "from-${sender}" ];
    assert node.config.inventory._module == [ "from-${sender}" ];
    assert
      map (definition: definition.file) node.options.inventory.values.definitionsWithLocations == [
        "${sourcePath} (sender `${sender}`, receiver `${name}`, destination `inventory.values`)"
        sourcePath
      ];
    assert builtins.all (entry: entry.assertion) node.config.assertions;
    true;

  nodes = {
    alpha = mkNode "alpha" "beta";
    beta = mkNode "beta" "alpha";
  };

  mkNode =
    name: receiver:
    lib.evalModules {
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
        (crossConfig.lib.mkModule { inherit name nodes optionPaths; })
        ./fixtures/factory-node.nix
        {
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
            description = "Assertions emitted by the forwarding module.";
          };
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
