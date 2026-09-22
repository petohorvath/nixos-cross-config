{
  checkAssertions,
  messagePattern,
  mkNodes,
}:
let
  rejections = import ./fixtures/contributions.nix { inherit mkNodes; };
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
{
  testOrdinaryHosts = {
    expr = config.networking.hosts."192.0.2.10";
    expected = [
      "beta.example"
      "local.example"
    ];
  };
  testForcedHosts = {
    expr = config.networking.hosts."192.0.2.20";
    expected = [
      "alpha.example"
      "beta.example"
    ];
  };
  testLocalProxy = {
    expr = virtualHost.locations."/".proxyPass;
    expected = "http://local:8000";
  };
  testForcedProxy = {
    expr = virtualHost.locations."/forced".proxyPass;
    expected = "http://alpha:8081";
  };
  testCustomProxy = {
    expr = virtualHost.locations."/custom".proxyPass;
    expected = "http://alpha:8082";
  };
  testOrderedAliases = {
    expr = virtualHost.serverAliases;
    expected = [
      "alpha.example"
      "early-local.example"
      "local.example"
      "late.example"
      "beta.example"
    ];
  };
  testForcedVirtualHost = {
    expr = forcedVirtualHost.locations."/".proxyPass;
    expected = "http://alpha:8083";
  };
  testDiscardedAliases = {
    expr = forcedVirtualHost.serverAliases;
    expected = [ ];
  };
  testLocalHosts = {
    expr = nodes.defaults.config.networking.hosts."192.0.2.40";
    expected = [ "local.example" ];
  };
  testDiscardedDefault = {
    expr = nodes.defaults.config.networking.hosts ? "192.0.2.30";
    expected = false;
  };
  testForcedOption = {
    expr = nodes.forced.config.networking.hosts."192.0.2.30";
    expected = [ "forced.example" ];
  };
  testDiscardedLocal = {
    expr = nodes.forced.config.networking.hosts ? "192.0.2.40";
    expected = false;
  };
  testAssertions = {
    expr = checkAssertions nodes;
    expected = true;
  };
}
// {
  testRejectsNestedConflict = {
    expr = rejections.nestedConflict;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "conflicting definition"
        "sender `sender`"
        "receiver `receiver`"
        "destination `services.nginx.virtualHosts`"
        "proxyPass"
      ];
    };
  };
}
