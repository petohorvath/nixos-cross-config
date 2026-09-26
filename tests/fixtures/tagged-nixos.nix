{ mkNodes }:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "services"
        "publishedEndpoint"
        "http"
        "upstream"
      ]
    ];
    modules = {
      application = { config, lib, ... }: {
        services.openssh.enable = true;
        crossConfig.nodes.proxy.services.publishedEndpoint.http.upstream =
          lib.mkIf config.services.openssh.enable "http://192.0.2.10:8080";
      };
      proxy = { config, lib, ... }: {
        options.services.publishedEndpoint = lib.mkOption {
          type = lib.types.attrTag {
            http = lib.mkOption {
              type = lib.types.submodule (
                { name, ... }: {
                  options = {
                    upstream = lib.mkOption {
                      type = lib.types.str;
                      readOnly = name != "http";
                      description = ''
                        An HTTP upstream contributed by the application.
                      '';
                    };
                    domain = lib.mkOption {
                      type = lib.types.str;
                      default = "application.example";
                      description = "The receiver-owned virtual host name.";
                    };
                  };
                }
              );
              description = "An HTTP publication with a writable upstream.";
            };
          };
          description = "A tagged service publication consumed by nginx.";
        };
        config = {
          networking.firewall.allowedTCPPorts = [ 80 ];
          services.nginx = {
            enable = true;
            virtualHosts.${config.services.publishedEndpoint.http.domain}.locations."/".proxyPass =
              config.services.publishedEndpoint.http.upstream;
          };
        };
      };
    };
  };
in
{
  publication = nodes.proxy.config.services.publishedEndpoint.http;
  proxyPass =
    nodes.proxy.config.services.nginx.virtualHosts."application.example".locations."/".proxyPass;
  firewallPorts = nodes.proxy.config.networking.firewall.allowedTCPPorts;
  assertions = builtins.mapAttrs (_: node: map (entry: entry.assertion) node.config.assertions) nodes;
}
