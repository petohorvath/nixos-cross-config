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
assert
  builtins.sort builtins.lessThan nodes.application.config.networking.hosts."192.0.2.10" == [
    "application-hostname.example"
    "local.example"
  ];
assert checkAssertions nodes;
true
