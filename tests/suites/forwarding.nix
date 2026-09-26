{
  allAssertionsPass,
  contributionRejections,
  lib,
  messagePattern,
  mkNodes,
  ...
}:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "hosts"
      ]
    ];
    modules = {
      sender = { lib, ... }: {
        crossConfig.nodes.receiver.networking.hosts = lib.mkDefinition {
          file = "generated-hosts.nix";
          value."192.0.2.10" = [ "application.example" ];
        };
      };
      receiver.networking.hosts."192.0.2.20" = [ "local.example" ];
    };
  };
in
{
  testHostName = {
    expr = nodes.receiver.config.networking.hostName;
    expected = "receiver-hostname";
  };
  testContribution = {
    expr = nodes.receiver.config.networking.hosts."192.0.2.10";
    expected = [
      "application.example"
    ];
  };
  testLocalValue = {
    expr = nodes.receiver.config.networking.hosts."192.0.2.20";
    expected = [ "local.example" ];
  };
  testDefinitionSource = {
    expr = lib.pipe nodes.receiver.options.networking.hosts.definitionsWithLocations [
      (builtins.filter (definition: definition.value ? "192.0.2.10"))
      (map (definition: definition.file))
    ];
    expected = [
      "generated-hosts.nix (sender `sender`, receiver `receiver`, destination `networking.hosts`)"
    ];
  };
  testAssertions = {
    expr = allAssertionsPass nodes;
    expected = true;
  };
  testRejectsInvalidPort = {
    expr = contributionRejections.incompatibleType;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "is not of type"
        "networking.firewall.allowedTCPPorts"
        "not-a-port"
        "sender `sender`"
        "receiver `receiver`"
      ];
    };
  };
  testRejectsContributedAssertion = {
    expr = contributionRejections.failedAssertion;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [ "The contributed receiver assertion failed." ];
    };
  };
}
