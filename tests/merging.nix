{ checkAssertions, mkNodes }:
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
          crossConfig.nodes = lib.mkMerge (
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
      beta.crossConfig.nodes.receiver = {
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
  config = nodes.receiver.config;
  virtualHost = config.services.nginx.virtualHosts."shared.example";
in
assert
  builtins.sort builtins.lessThan config.networking.hosts."192.0.2.10" == [
    "alpha.example"
    "beta.example"
    "gamma.example"
    "local.example"
  ];
assert
  builtins.sort builtins.lessThan config.networking.firewall.allowedTCPPorts == [
    443
    8080
    8081
    9090
  ];
assert virtualHost.serverAliases == [ "alias.example" ];
assert virtualHost.locations."/alpha".proxyPass == "http://192.0.2.10:8080";
assert virtualHost.locations."/gamma".proxyPass == "http://192.0.2.10:8081";
assert !(virtualHost.locations ? "/disabled");
assert virtualHost.locations."/beta".proxyPass == "http://192.0.2.20:9090";
assert virtualHost.locations."/local".root == "/srv/local";
assert checkAssertions nodes;
true
