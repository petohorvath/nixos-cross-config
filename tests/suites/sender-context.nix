{ checkAssertions, mkNodes, ... }:
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
  receiverConfig = nodes.receiver.config;
  virtualHost = receiverConfig.services.nginx.virtualHosts."shared.example";
in
{
  testReceiverDomain = {
    expr = receiverConfig.networking.domain;
    expected = "receiver.example";
  };
  testSenderDomain = {
    expr = receiverConfig.networking.search;
    expected = [ "sender.example" ];
  };
  testReceiverServerName = {
    expr = virtualHost.serverName;
    expected = "receiver-refined.example";
  };
  testAliases = {
    expr = virtualHost.serverAliases;
    expected = [
      "shared.example.sender.example"
      "local.example"
      "receiver-refined.example.sender-hostname"
    ];
  };
  testSenderLocation = {
    expr = virtualHost.locations."/captured".proxyPass;
    expected = "http://sender-hostname:8080";
  };
  testNestedRoot = {
    expr = virtualHost.locations."/nested".root;
    expected = "/srv/receiver";
  };
  testNestedConfig = {
    expr = virtualHost.locations."/nested".extraConfig;
    expected = "add_header X-Root /srv/receiver;";
  };
  testDisabledLocation = {
    expr = virtualHost.locations ? "/disabled";
    expected = false;
  };
  testAssertions = {
    expr = checkAssertions nodes;
    expected = true;
  };
}
