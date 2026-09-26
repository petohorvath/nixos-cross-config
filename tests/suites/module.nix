{
  allAssertionsPass,
  evaluateModule,
  lib,
  ...
}:
let
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
    evaluateModule {
      specialArgs.lib = lib // {
        mkOption = arguments: lib.mkOption arguments // { receiverLibrary = name; };
      };
      modules = [
        {
          options = {
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
              contributions.${receiver}.inventory.values = lib.mkBefore [ "from-${name}" ];
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
  testAlphaReceiverLibrary = {
    expr = nodes.alpha.options.crossConfig.contributions.receiverLibrary;
    expected = "alpha";
  };
  testBetaReceiverLibrary = {
    expr = nodes.beta.options.crossConfig.contributions.receiverLibrary;
    expected = "beta";
  };
  testAssertions = {
    expr = allAssertionsPass nodes;
    expected = true;
  };
}
