{
  crossConfig,
  flakeParts,
  mkNodes,
  nixpkgs,
}:
let
  localConflict = domainFailure {
    sender.crossConfig.nodes.receiver.networking.domain = "sender.example";
    receiver.networking.domain = "local.example";
  };
  senderConflict = domainFailure {
    alpha.crossConfig.nodes.receiver.networking.domain = "alpha.example";
    beta.crossConfig.nodes.receiver.networking.domain = "beta.example";
    receiver = { };
  };
  forcedLocalConflict = domainFailure {
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
  customSenderConflict = domainFailure {
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
  sameSenderConflict = domainFailure {
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
  domainFailure =
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
  inherit
    customSenderConflict
    forcedLocalConflict
    localConflict
    sameSenderConflict
    senderConflict
    ;
  nestedConflict =
    nestedConflict.receiver.config.services.nginx.virtualHosts."shared.example".locations."/".proxyPass;
  incompatibleType = incompatibleType.receiver.config.networking.firewall.allowedTCPPorts;
  failedAssertion = failedAssertion.receiver.config.system.build.toplevel.drvPath;
}
// import ./destination-failures.nix { inherit mkNodes; }
// import ./tagged-failures.nix { inherit mkNodes; }
// import ./module-failures.nix { inherit crossConfig nixpkgs; }
// import ./flake-module-failures.nix { inherit crossConfig flakeParts; }
