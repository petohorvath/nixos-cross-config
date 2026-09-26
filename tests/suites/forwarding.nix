{
  checkAssertions,
  lib,
  messagePattern,
  mkNodes,
  ...
}:
let
  rejections = import ../fixtures/contributions.nix { inherit mkNodes; };
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
    expr = map (definition: definition.file) (
      builtins.filter (
        definition: definition.value ? "192.0.2.10"
      ) nodes.receiver.options.networking.hosts.definitionsWithLocations
    );
    expected = [
      (lib.concatStrings [
        "generated-hosts.nix (sender `sender`, receiver `receiver`, "
        "destination `networking.hosts`)"
      ])
    ];
  };
  testAssertions = {
    expr = checkAssertions nodes;
    expected = true;
  };
  testRejectsInvalidPort = {
    expr = rejections.incompatibleType;
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
    expr = rejections.failedAssertion;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [ "The contributed receiver assertion failed." ];
    };
  };
}
