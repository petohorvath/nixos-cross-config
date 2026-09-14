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
      alpha =
        { config, ... }:
        {
          networking.hosts."192.0.2.20" = [ "alpha-local.example" ];
          crossConfig.nodes.beta.networking.hosts."192.0.2.10" = [
            "${config.networking.hostName}.example"
          ];
        };
      beta =
        { config, ... }:
        {
          networking.hosts."192.0.2.10" = [ "beta-local.example" ];
          crossConfig.nodes.alpha.networking.hosts."192.0.2.20" = [
            "${config.networking.hostName}.example"
          ];
        };
    };
  };
in
assert
  builtins.sort builtins.lessThan nodes.alpha.config.networking.hosts."192.0.2.20" == [
    "alpha-local.example"
    "beta-hostname.example"
  ];
assert
  builtins.sort builtins.lessThan nodes.beta.config.networking.hosts."192.0.2.10" == [
    "alpha-hostname.example"
    "beta-local.example"
  ];
assert checkAssertions nodes;
true
