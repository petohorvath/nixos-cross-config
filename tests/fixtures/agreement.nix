{ checkAssertions, mkNodeCollection }:
let
  hostsPath = [
    "networking"
    "hosts"
  ];
  domainPath = [
    "networking"
    "domain"
  ];

  mkNodes =
    {
      receiver ? { },
      sender ? { },
      extraNodes ? { },
    }:
    mkNodeCollection {
      optionPaths = [
        hostsPath
        domainPath
      ];
      inherit extraNodes;
      modules = {
        inherit receiver;
        sender = {
          imports = [ sender ];
          crossConfig.contributions.receiver.networking.hosts."192.0.2.10" = [ "sender.example" ];
        };
      };
    };

  differentPaths = mkNodes {
    receiver =
      { lib, ... }:
      {
        crossConfig.optionPaths = lib.mkForce [ domainPath ];
      };
  };
  idleReceiver = mkNodes {
    receiver =
      { lib, ... }:
      {
        crossConfig.optionPaths = lib.mkForce [ ];
      };
  };
  missingSender = mkNodes {
    receiver =
      { lib, ... }:
      {
        crossConfig.nodeConfigurations = lib.mkForce { inherit (missingSender) receiver; };
      };
  };
  renamedSender = mkNodes {
    sender =
      { lib, ... }:
      {
        crossConfig.name = lib.mkForce "renamed";
      };
  };
  plainReceiver = mkNodes {
    sender.crossConfig.contributions.plain = { };
    extraNodes.plain.config = { };
  };
in
builtins.mapAttrs (_: checkAssertions) {
  differentPathsSender = differentPaths.sender;
  differentPathsReceiver = differentPaths.receiver;
  idleReceiverSender = idleReceiver.sender;
  missingSender = missingSender.sender;
  renamedSender = renamedSender.sender;
  renamedSenderReceiver = renamedSender.receiver;
  plainReceiver = plainReceiver.sender;
}
