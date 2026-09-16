{ checkAssertions, mkNodes }:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "hosts"
      ]
      [
        "services"
        "nginx"
        "virtualHosts"
      ]
    ];
    modules = {
      alpha =
        { lib, ... }:
        {
          crossConfig.nodes = {
            receiver = {
              networking.hosts = {
                "192.0.2.10" = lib.mkDefault [ "default.example" ];
                "192.0.2.20" = lib.mkForce (lib.mkBefore [ "alpha.example" ]);
              };
              services.nginx.virtualHosts = {
                "shared.example" = {
                  locations = {
                    "/".proxyPass = lib.mkDefault "http://alpha:8080";
                    "/forced".proxyPass = lib.mkForce "http://alpha:8081";
                    "/custom".proxyPass = lib.mkOverride 75 "http://alpha:8082";
                  };
                  serverAliases = lib.mkMerge [
                    (lib.mkBefore [ "alpha.example" ])
                    (lib.mkOrder 1250 [ "late.example" ])
                  ];
                };
                "forced.example" = lib.mkForce {
                  locations."/".proxyPass = "http://alpha:8083";
                };
              };
            };
            defaults.networking.hosts = lib.mkDefault {
              "192.0.2.30" = [ "discarded.example" ];
            };
            forced.networking.hosts = lib.mkForce {
              "192.0.2.30" = [ "forced.example" ];
            };
          };
        };
      beta =
        { lib, ... }:
        {
          crossConfig.nodes.receiver = {
            networking.hosts = {
              "192.0.2.10" = lib.mkBefore [ "beta.example" ];
              "192.0.2.20" = lib.mkForce (lib.mkAfter [ "beta.example" ]);
            };
            services.nginx.virtualHosts."shared.example" = {
              locations = {
                "/".proxyPass = lib.mkDefault "http://beta:9090";
                "/forced".proxyPass = "http://beta:9091";
                "/custom".proxyPass = lib.mkOverride 90 "http://beta:9092";
              };
              serverAliases = lib.mkAfter [ "beta.example" ];
            };
          };
        };
      receiver =
        { lib, ... }:
        {
          networking.hosts = {
            "192.0.2.10" = [ "local.example" ];
            "192.0.2.20" = [ "discarded.example" ];
          };
          services.nginx.virtualHosts = {
            "shared.example" = {
              locations = {
                "/".proxyPass = "http://local:8000";
                "/forced".proxyPass = "http://local:8001";
                "/custom".proxyPass = lib.mkOverride 80 "http://local:8002";
              };
              serverAliases = lib.mkMerge [
                [ "local.example" ]
                (lib.mkOrder 750 [ "early-local.example" ])
              ];
            };
            "forced.example".serverAliases = [ "discarded.example" ];
          };
        };
      defaults.networking.hosts."192.0.2.40" = [ "local.example" ];
      forced.networking.hosts."192.0.2.40" = [ "discarded.example" ];
    };
  };
  config = nodes.receiver.config;
  virtualHost = config.services.nginx.virtualHosts."shared.example";
  forcedVirtualHost = config.services.nginx.virtualHosts."forced.example";
in
assert
  config.networking.hosts."192.0.2.10" == [
    "beta.example"
    "local.example"
  ];
assert
  config.networking.hosts."192.0.2.20" == [
    "alpha.example"
    "beta.example"
  ];
assert virtualHost.locations."/".proxyPass == "http://local:8000";
assert virtualHost.locations."/forced".proxyPass == "http://alpha:8081";
assert virtualHost.locations."/custom".proxyPass == "http://alpha:8082";
assert
  virtualHost.serverAliases == [
    "alpha.example"
    "early-local.example"
    "local.example"
    "late.example"
    "beta.example"
  ];
assert forcedVirtualHost.locations."/".proxyPass == "http://alpha:8083";
assert forcedVirtualHost.serverAliases == [ ];
assert nodes.defaults.config.networking.hosts."192.0.2.40" == [ "local.example" ];
assert !(nodes.defaults.config.networking.hosts ? "192.0.2.30");
assert nodes.forced.config.networking.hosts."192.0.2.30" == [ "forced.example" ];
assert !(nodes.forced.config.networking.hosts ? "192.0.2.40");
assert checkAssertions nodes;
true
