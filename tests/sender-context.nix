{ checkAssertions, mkNodes }:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "search"
      ]
      [
        "services"
        "nginx"
        "virtualHosts"
      ]
    ];
    modules = {
      sender =
        { config, lib, ... }:
        let
          senderConfig = config;
        in
        {
          networking.domain = "sender.example";
          services.nginx.virtualHosts."shared.example".serverName = "sender-local.example";
          crossConfig.nodes.receiver = {
            networking.search = [ config.networking.domain ];
            services.nginx.virtualHosts."shared.example" =
              { config, name, ... }:
              {
                serverName = lib.mkDefault "contributed.example";
                serverAliases = lib.mkMerge [
                  (lib.mkIf (senderConfig.networking.domain == "sender.example") (
                    lib.mkBefore [ "${name}.${senderConfig.networking.domain}" ]
                  ))
                  (lib.mkIf (config.serverName == "receiver-refined.example") (
                    lib.mkAfter [ "${config.serverName}.${senderConfig.networking.hostName}" ]
                  ))
                ];
                locations = lib.mkMerge [
                  {
                    "/captured".proxyPass = "http://${senderConfig.networking.hostName}:8080";
                    "/nested" =
                      { config, ... }:
                      {
                        root = lib.mkDefault "/srv/contributed";
                        extraConfig = "add_header X-Root ${config.root};";
                      };
                  }
                  (lib.mkIf (config.serverName == "sender-local.example") {
                    "/disabled".return = "500";
                  })
                ];
              };
          };
        };
      receiver = {
        networking.domain = "receiver.example";
        services.nginx.virtualHosts."shared.example" = {
          serverName = "receiver-refined.example";
          serverAliases = [ "local.example" ];
          locations."/nested".root = "/srv/receiver";
        };
      };
    };
  };
  config = nodes.receiver.config;
  virtualHost = config.services.nginx.virtualHosts."shared.example";
in
assert config.networking.domain == "receiver.example";
assert config.networking.search == [ "sender.example" ];
assert virtualHost.serverName == "receiver-refined.example";
assert
  virtualHost.serverAliases == [
    "shared.example.sender.example"
    "local.example"
    "receiver-refined.example.sender-hostname"
  ];
assert virtualHost.locations."/captured".proxyPass == "http://sender-hostname:8080";
assert virtualHost.locations."/nested".root == "/srv/receiver";
assert virtualHost.locations."/nested".extraConfig == "add_header X-Root /srv/receiver;";
assert !(virtualHost.locations ? "/disabled");
assert checkAssertions nodes;
true
