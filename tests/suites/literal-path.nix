{ allAssertionsPass, mkNodes, ... }:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "environment"
        "etc"
        "application.conf"
        "text"
      ]
    ];
    modules = {
      sender.crossConfig.contributions.receiver = {
        environment.etc."application.conf".text = "port=8080\n";
      };
      receiver.environment.etc."application.conf".mode = "0640";
    };
  };
  entry = nodes.receiver.config.environment.etc."application.conf";
in
{
  testText = {
    expr = entry.text;
    expected = "port=8080\n";
  };
  testMode = {
    expr = entry.mode;
    expected = "0640";
  };
  testTarget = {
    expr = entry.target;
    expected = "application.conf";
  };
  testAssertions = {
    expr = allAssertionsPass nodes;
    expected = true;
  };
}
