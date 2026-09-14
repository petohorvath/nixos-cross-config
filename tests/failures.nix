{ mkNodes }:
let
  localConflict = mkNodes {
    optionPaths = [
      [
        "networking"
        "domain"
      ]
    ];
    modules = {
      sender.crossConfig.nodes.receiver.networking.domain = "sender.example";
      receiver.networking.domain = "local.example";
    };
  };
  senderConflict = mkNodes {
    optionPaths = [
      [
        "networking"
        "domain"
      ]
    ];
    modules = {
      alpha.crossConfig.nodes.receiver.networking.domain = "alpha.example";
      beta.crossConfig.nodes.receiver.networking.domain = "beta.example";
      receiver = { };
    };
  };
  forcedLocalConflict = mkNodes {
    optionPaths = [
      [
        "networking"
        "domain"
      ]
    ];
    modules = {
      sender =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.networking.domain = lib.mkForce "sender.example";
        };
      receiver =
        { lib, ... }:
        {
          networking.domain = lib.mkForce "local.example";
        };
    };
  };
  customSenderConflict = mkNodes {
    optionPaths = [
      [
        "networking"
        "domain"
      ]
    ];
    modules = {
      alpha =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.networking.domain = lib.mkOverride 75 "alpha.example";
        };
      beta =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.networking.domain = lib.mkOverride 75 "beta.example";
        };
      receiver.networking.domain = "discarded.example";
    };
  };
  sameSenderConflict = mkNodes {
    optionPaths = [
      [
        "networking"
        "domain"
      ]
    ];
    modules = {
      sender =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.networking.domain = lib.mkMerge [
            (lib.mkOverride 75 "first.example")
            (lib.mkOverride 75 "second.example")
          ];
        };
      receiver = { };
    };
  };
  nestedConflict = mkNodes {
    optionPaths = [
      [
        "services"
        "nginx"
        "virtualHosts"
      ]
    ];
    modules = {
      sender =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.services.nginx.virtualHosts."shared.example" = {
            locations."/".proxyPass = lib.mkForce "http://sender:8080";
          };
        };
      receiver =
        { lib, ... }:
        {
          services.nginx.virtualHosts."shared.example" = {
            locations."/".proxyPass = lib.mkForce "http://receiver:8080";
          };
        };
    };
  };
  incompatibleType = mkNodes {
    optionPaths = [
      [
        "networking"
        "firewall"
        "allowedTCPPorts"
      ]
    ];
    modules = {
      sender.crossConfig.nodes.receiver.networking.firewall.allowedTCPPorts = [
        "not-a-port"
      ];
      receiver = { };
    };
  };
  failedAssertion = mkNodes {
    optionPaths = [
      [ "assertions" ]
    ];
    modules = {
      sender.crossConfig.nodes.receiver.assertions = [
        {
          assertion = false;
          message = "The contributed receiver assertion failed.";
        }
      ];
      receiver = { };
    };
  };
in
{
  localConflict = localConflict.receiver.config.networking.domain;
  senderConflict = senderConflict.receiver.config.networking.domain;
  forcedLocalConflict = forcedLocalConflict.receiver.config.networking.domain;
  customSenderConflict = customSenderConflict.receiver.config.networking.domain;
  sameSenderConflict = sameSenderConflict.receiver.config.networking.domain;
  nestedConflict =
    nestedConflict.receiver.config.services.nginx.virtualHosts."shared.example".locations."/".proxyPass;
  incompatibleType = incompatibleType.receiver.config.networking.firewall.allowedTCPPorts;
  failedAssertion = failedAssertion.receiver.config.system.build.toplevel.drvPath;
}
// import ./destination-failures.nix { inherit mkNodes; }
