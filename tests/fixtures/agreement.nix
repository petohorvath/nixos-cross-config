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
  excludedSender = mkNodes {
    receiver =
      { lib, ... }:
      {
        crossConfig.nodeConfigurations = lib.mkForce { inherit (excludedSender) receiver; };
      };
  };
  # The sender contributes to its own key, which its identity does not match.
  renamedSender = mkNodes {
    sender =
      { lib, ... }:
      {
        crossConfig.name = lib.mkForce "renamed";
        crossConfig.contributions.sender.networking.hosts."192.0.2.20" = [ "self.example" ];
      };
  };
  # An idle sender still checks the receivers it targets.
  idleSender = mkNodes {
    sender =
      { lib, ... }:
      {
        crossConfig.optionPaths = lib.mkForce [ ];
        crossConfig.contributions = lib.mkForce { receiver = { }; };
      };
  };
  plainReceiver = mkNodes {
    sender.crossConfig.contributions.plain = { };
    extraNodes.plain.config = { };
  };
in
builtins.mapAttrs (_: checkAssertions) {
  differentPathsOnSender = differentPaths.sender;
  differentPathsOnReceiver = differentPaths.receiver;
  idleReceiverOnSender = idleReceiver.sender;
  idleSenderOnSender = idleSender.sender;
  excludedSenderOnSender = excludedSender.sender;
  renamedSenderOnSender = renamedSender.sender;
  renamedSenderOnReceiver = renamedSender.receiver;
  plainReceiverOnSender = plainReceiver.sender;
}
