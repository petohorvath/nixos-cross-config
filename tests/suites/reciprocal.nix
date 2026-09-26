{
  allAssertionsPass,
  mkNodes,
  valueCycle,
  ...
}:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "hosts"
      ]
    ];
    modules = {
      alpha =
        { config, ... }:
        {
          networking.hosts."192.0.2.20" = [ "alpha-local.example" ];
          crossConfig.contributions.beta.networking.hosts."192.0.2.10" = [
            "${config.networking.hostName}.example"
          ];
        };
      beta =
        { config, ... }:
        {
          networking.hosts."192.0.2.10" = [ "beta-local.example" ];
          crossConfig.contributions.alpha.networking.hosts."192.0.2.20" = [
            "${config.networking.hostName}.example"
          ];
        };
    };
  };
in
{
  testAlphaHosts = {
    expr = builtins.sort builtins.lessThan nodes.alpha.config.networking.hosts."192.0.2.20";
    expected = [
      "alpha-local.example"
      "beta-hostname.example"
    ];
  };
  testBetaHosts = {
    expr = builtins.sort builtins.lessThan nodes.beta.config.networking.hosts."192.0.2.10";
    expected = [
      "alpha-hostname.example"
      "beta-local.example"
    ];
  };
  testAssertions = {
    expr = allAssertionsPass nodes;
    expected = true;
  };
  testRejectsValueCycle = {
    expr = valueCycle;
    expectedError = {
      type = "EvalError";
      msg = "infinite recursion encountered";
    };
  };
}
