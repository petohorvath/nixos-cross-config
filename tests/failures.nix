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
  incompatibleType = incompatibleType.receiver.config.networking.firewall.allowedTCPPorts;
  failedAssertion = failedAssertion.receiver.config.system.build.toplevel.drvPath;
}
