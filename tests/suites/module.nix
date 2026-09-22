{ crossConfig, nixpkgs, ... }:
let
  inherit (nixpkgs) lib;
  nodes = {
    alpha = mkNode "alpha" "beta";
    beta = mkNode "beta" "alpha";
  };
  mkNode =
    name: receiver:
    lib.evalModules {
      specialArgs.lib = lib // {
        mkOption = arguments: lib.mkOption arguments // { receiverLibrary = name; };
      };
      modules = [
        crossConfig.nixosModules.default
        {
          options = {
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
              description = "Assertions emitted by participating modules.";
            };
            inventory.values = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              apply = map (value: "${name}:${value}");
              description = "Values marked by the receiver after merging.";
            };
          };
          config = {
            crossConfig = {
              inherit name;
              nodeConfigurations = nodes;
              optionPaths = [
                [
                  "inventory"
                  "values"
                ]
              ];
              nodes.${receiver}.inventory.values = lib.mkBefore [ "from-${name}" ];
            };
            inventory.values = [ "local-${name}" ];
          };
        }
      ];
    };
in
{
  testAlphaAppliedValues = {
    expr = nodes.alpha.config.inventory.values;
    expected = [
      "alpha:from-beta"
      "alpha:local-alpha"
    ];
  };
  testBetaAppliedValues = {
    expr = nodes.beta.config.inventory.values;
    expected = [
      "beta:from-alpha"
      "beta:local-beta"
    ];
  };
  testAlphaLibrary = {
    expr = nodes.alpha.options.crossConfig.nodes.receiverLibrary;
    expected = "alpha";
  };
  testBetaLibrary = {
    expr = nodes.beta.options.crossConfig.nodes.receiverLibrary;
    expected = "beta";
  };
  testAssertions = {
    expr = builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions) (
      builtins.attrValues nodes
    );
    expected = true;
  };
}
