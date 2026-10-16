{ helpers, lib, ... }:
let
  inherit (helpers) allAssertionsPass mkNodeCollection mkReceiverLib;
  receivers = {
    alpha = "beta";
    beta = "alpha";
  };
  nodes = mkNodeCollection {
    evaluator = "modules";
    specialArgs = name: { lib = mkReceiverLib name; };
    optionPaths = [
      [
        "inventory"
        "values"
      ]
    ];
    modules = lib.mapAttrs (name: receiver: {
      options = {
        inventory.values = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          apply = map (value: "${name}:${value}");
          description = "Values marked by the receiver after merging.";
        };
      };
      config = {
        crossConfig.contributions.${receiver}.inventory.values = lib.mkBefore [ "from-${name}" ];
        inventory.values = [ "local-${name}" ];
      };
    }) receivers;
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
