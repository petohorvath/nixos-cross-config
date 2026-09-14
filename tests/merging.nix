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
      alpha.crossConfig.nodes.receiver = {
        networking.hosts."192.0.2.10" = [ "alpha.example" ];
        networking.firewall.allowedTCPPorts = [ 8080 ];
        services.nginx.virtualHosts."shared.example".locations."/alpha" = {
          proxyPass = "http://192.0.2.10:8080";
        };
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
    "local.example"
  ];
assert
  builtins.sort builtins.lessThan config.networking.firewall.allowedTCPPorts == [
    443
    8080
    9090
  ];
assert virtualHost.serverAliases == [ "alias.example" ];
assert virtualHost.locations."/alpha".proxyPass == "http://192.0.2.10:8080";
assert virtualHost.locations."/beta".proxyPass == "http://192.0.2.20:9090";
assert virtualHost.locations."/local".root == "/srv/local";
assert checkAssertions nodes;
true
