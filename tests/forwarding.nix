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
assert nodes.receiver.config.networking.hostName == "receiver-hostname";
assert
  nodes.receiver.config.networking.hosts."192.0.2.10" == [
    "application.example"
  ];
assert nodes.receiver.config.networking.hosts."192.0.2.20" == [ "local.example" ];
assert checkAssertions nodes;
true
