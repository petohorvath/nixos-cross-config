{ mkNodes }:
let
  evaluateReceiverDomain =
    modules:
    (mkNodes {
      optionPaths = [
        [
          "networking"
          "domain"
        ]
      ];
      inherit modules;
    }).receiver.config.networking.domain;
in
{
  localConflict = evaluateReceiverDomain {
    sender.crossConfig.contributions.receiver.networking.domain = "sender.example";
    receiver.networking.domain = "local.example";
  };
  senderConflict = evaluateReceiverDomain {
    alpha.crossConfig.contributions.receiver.networking.domain = "alpha.example";
    beta.crossConfig.contributions.receiver.networking.domain = "beta.example";
    receiver = { };
  };
  forcedLocalConflict = evaluateReceiverDomain {
    sender =
      { lib, ... }:
      {
        crossConfig.contributions.receiver.networking.domain = lib.mkForce "sender.example";
      };
    receiver =
      { lib, ... }:
      {
        networking.domain = lib.mkForce "local.example";
      };
  };
  customSenderConflict = evaluateReceiverDomain {
    alpha =
      { lib, ... }:
      {
        crossConfig.contributions.receiver.networking.domain = lib.mkOverride 75 "alpha.example";
      };
    beta =
      { lib, ... }:
      {
        crossConfig.contributions.receiver.networking.domain = lib.mkOverride 75 "beta.example";
      };
    receiver.networking.domain = "discarded.example";
  };
  sameSenderConflict = evaluateReceiverDomain {
    sender =
      { lib, ... }:
      {
        crossConfig.contributions.receiver.networking.domain = lib.mkMerge [
          (lib.mkOverride 75 "first.example")
          (lib.mkOverride 75 "second.example")
        ];
      };
    receiver = { };
  };
  nestedConflict =
    (mkNodes {
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
            crossConfig.contributions.receiver.services.nginx.virtualHosts."shared.example" = {
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
    }).receiver.config.services.nginx.virtualHosts."shared.example".locations."/".proxyPass;
  incompatibleType =
    (mkNodes {
      optionPaths = [
        [
          "networking"
          "firewall"
          "allowedTCPPorts"
        ]
      ];
      modules = {
        sender.crossConfig.contributions.receiver.networking.firewall.allowedTCPPorts = [
          "not-a-port"
        ];
        receiver = { };
      };
    }).receiver.config.networking.firewall.allowedTCPPorts;
  failedAssertion =
    (mkNodes {
      optionPaths = [
        [ "assertions" ]
      ];
      modules = {
        sender.crossConfig.contributions.receiver.assertions = [
          {
            assertion = false;
            message = "The contributed receiver assertion failed.";
          }
        ];
        receiver = { };
      };
    }).receiver.config.system.build.toplevel.drvPath;
}
