{ checkAssertions, mkNodes }:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "hosts"
      ]
    ];
    modules.application =
      { config, ... }:
      {
        networking.hosts."192.0.2.10" = [ "local.example" ];
        crossConfig.nodes.application.networking.hosts."192.0.2.10" = [
          "${config.networking.hostName}.example"
        ];
      };
  };
in
{
  testHosts = {
    expr = builtins.sort builtins.lessThan nodes.application.config.networking.hosts."192.0.2.10";
    expected = [
      "application-hostname.example"
      "local.example"
    ];
  };
  testAssertions = {
    expr = checkAssertions nodes;
    expected = true;
  };
}
