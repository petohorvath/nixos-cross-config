{ checkAssertions, mkNodes }:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "hosts"
      ]
    ];
    modules = {
      sender.crossConfig.nodes.receiver.networking.hosts."192.0.2.10" = [
        "application.example"
      ];
      receiver.networking.hosts."192.0.2.20" = [ "local.example" ];
    };
  };
in
{
  testHostName = {
    expr = nodes.receiver.config.networking.hostName;
    expected = "receiver-hostname";
  };
  testContribution = {
    expr = nodes.receiver.config.networking.hosts."192.0.2.10";
    expected = [
      "application.example"
    ];
  };
  testLocalValue = {
    expr = nodes.receiver.config.networking.hosts."192.0.2.20";
    expected = [ "local.example" ];
  };
  testAssertions = {
    expr = checkAssertions nodes;
    expected = true;
  };
}
