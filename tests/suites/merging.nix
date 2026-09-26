{
  allAssertionsPass,
  contributionRejections,
  messagePattern,
  mkNodes,
  ...
}:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "hosts"
      ]
      [
        "networking"
        "firewall"
        "allowedTCPPorts"
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
        let
          exports = [
            {
              name = "alpha";
              receiver = "receiver";
              port = 8080;
              enable = true;
            }
            {
              name = "gamma";
              receiver = "receiver";
              port = 8081;
              enable = true;
            }
            {
              name = "disabled";
              receiver = "receiver";
              port = 8082;
              enable = false;
            }
          ];
        in
        {
          crossConfig.contributions = lib.mkMerge (
            map (
              export:
              lib.mkIf export.enable {
                ${export.receiver} = {
                  networking.hosts."192.0.2.10" = [ "${export.name}.example" ];
                  networking.firewall.allowedTCPPorts = [ export.port ];
                  services.nginx.virtualHosts."shared.example" = {
                    locations."/${export.name}".proxyPass = "http://192.0.2.10:${toString export.port}";
                  };
                };
              }
            ) exports
          );
        };
      beta.crossConfig.contributions.receiver = {
        networking.hosts."192.0.2.10" = [ "beta.example" ];
        networking.firewall.allowedTCPPorts = [ 9090 ];
        services.nginx.virtualHosts."shared.example".locations."/beta" = {
          proxyPass = "http://192.0.2.20:9090";
        };
      };
      receiver = {
        networking.hosts."192.0.2.10" = [ "local.example" ];
        networking.firewall.allowedTCPPorts = [ 443 ];
        services.nginx.virtualHosts."shared.example" = {
          serverAliases = [ "alias.example" ];
          locations."/local".root = "/srv/local";
        };
      };
    };
  };
  receiverConfig = nodes.receiver.config;
  virtualHost = receiverConfig.services.nginx.virtualHosts."shared.example";
in
{
  testHosts = {
    expr = builtins.sort builtins.lessThan receiverConfig.networking.hosts."192.0.2.10";
    expected = [
      "alpha.example"
      "beta.example"
      "gamma.example"
      "local.example"
    ];
  };
  testPorts = {
    expr = builtins.sort builtins.lessThan receiverConfig.networking.firewall.allowedTCPPorts;
    expected = [
      443
      8080
      8081
      9090
    ];
  };
  testLocalAliases = {
    expr = virtualHost.serverAliases;
    expected = [ "alias.example" ];
  };
  testAlphaLocation = {
    expr = virtualHost.locations."/alpha".proxyPass;
    expected = "http://192.0.2.10:8080";
  };
  testGammaLocation = {
    expr = virtualHost.locations."/gamma".proxyPass;
    expected = "http://192.0.2.10:8081";
  };
  testDisabledLocation = {
    expr = virtualHost.locations ? "/disabled";
    expected = false;
  };
  testBetaLocation = {
    expr = virtualHost.locations."/beta".proxyPass;
    expected = "http://192.0.2.20:9090";
  };
  testLocalLocation = {
    expr = virtualHost.locations."/local".root;
    expected = "/srv/local";
  };
  testAssertions = {
    expr = allAssertionsPass nodes;
    expected = true;
  };
  testRejectsLocalConflict = {
    expr = contributionRejections.localConflict;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "conflicting definition"
        "sender `sender`"
        "receiver `receiver`"
        "destination `networking.domain`"
      ];
    };
  };
  testRejectsSenderConflict = {
    expr = contributionRejections.senderConflict;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "conflicting definition"
        "sender `alpha`"
        "sender `beta`"
        "receiver `receiver`"
        "destination `networking.domain`"
      ];
    };
  };
}
