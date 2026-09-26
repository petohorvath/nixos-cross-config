{ allAssertionsPass, mkNodes, ... }:
let
  senderModule =
    { config, lib, ... }:
    let
      enable = config.services.openssh.enable;
      senderHostName =
        if enable then
          config.networking.hostName
        else
          throw "A disabled integration evaluated its payload.";
    in
    {
      config = lib.mkMerge [
        {
          crossConfig.nodes = lib.mkMerge [
            {
              receiver = {
                networking.hosts = lib.mkMerge [
                  (lib.mkIf enable { "192.0.2.10" = [ senderHostName ]; })
                  (lib.mkIf enable { "192.0.2.11" = [ senderHostName ]; })
                ];
                networking.search = lib.mkIf false (throw "A disabled option contribution was evaluated.");
              };
            }
            (lib.mkIf enable (
              lib.mkMerge [
                { receiver.networking.hosts."192.0.2.20" = [ senderHostName ]; }
                { receiver.networking.hosts."192.0.2.21" = [ senderHostName ]; }
              ]
            ))
            {
              receiver = lib.mkIf enable (
                lib.mkMerge [
                  { networking.hosts."192.0.2.30" = [ senderHostName ]; }
                  { networking.hosts."192.0.2.31" = [ senderHostName ]; }
                ]
              );
            }
            {
              receiver.networking = lib.mkIf enable (
                lib.mkMerge [
                  { hosts."192.0.2.35" = [ senderHostName ]; }
                  { hosts."192.0.2.36" = [ senderHostName ]; }
                ]
              );
            }
          ];
        }
        (lib.mkIf enable {
          crossConfig.nodes.receiver.networking.hosts."192.0.2.40" = [ senderHostName ];
        })
      ];
    };
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "hosts"
      ]
      [
        "networking"
        "search"
      ]
    ];
    modules = {
      enabled = {
        imports = [ senderModule ];
        services.openssh.enable = true;
      };
      disabled = {
        imports = [ senderModule ];
        services.openssh.enable = false;
      };
      receiver = {
        networking.hosts."192.0.2.50" = [ "local.example" ];
        networking.search = [ "local.example" ];
      };
    };
  };
  receiverConfig = nodes.receiver.config;
in
{
  testEnabledBranches = {
    expr =
      builtins.all (address: receiverConfig.networking.hosts.${address} == [ "enabled-hostname" ])
        [
          "192.0.2.10"
          "192.0.2.11"
          "192.0.2.20"
          "192.0.2.21"
          "192.0.2.30"
          "192.0.2.31"
          "192.0.2.35"
          "192.0.2.36"
          "192.0.2.40"
        ];
    expected = true;
  };
  testLocalHosts = {
    expr = receiverConfig.networking.hosts."192.0.2.50";
    expected = [ "local.example" ];
  };
  testSkipsDisabledSearch = {
    expr = receiverConfig.networking.search;
    expected = [ "local.example" ];
  };
  testAssertions = {
    expr = allAssertionsPass nodes;
    expected = true;
  };
}
