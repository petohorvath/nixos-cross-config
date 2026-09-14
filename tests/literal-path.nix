{ checkAssertions, mkNodes }:
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
      sender.crossConfig.nodes.receiver = {
        environment.etc."application.conf".text = "port=8080\n";
      };
      receiver.environment.etc."application.conf".mode = "0640";
    };
  };
  entry = nodes.receiver.config.environment.etc."application.conf";
in
assert entry.text == "port=8080\n";
assert entry.mode == "0640";
assert entry.target == "application.conf";
assert checkAssertions nodes;
true
