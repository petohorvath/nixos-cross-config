{ checkAssertions, mkNodes }:
let
  rejections = import ./fixtures/contributions.nix { inherit mkNodes; };
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "hosts"
      ]
    ];
    modules = {
      sender.crossConfig.nodes.receiver.networking.hosts."192.0.2.10" = [
        "application.example"
      ];
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
  testAssertions = {
    expr = checkAssertions nodes;
    expected = true;
  };
}
// {
  testRejectsInvalidPort = {
    expr = rejections.incompatibleType;
    expectedError = {
      type = "ThrownError";
      msg = "is not of type";
      trace = [
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
      msg = "The contributed receiver assertion failed.";
      trace = [ "The contributed receiver assertion failed." ];
    };
  };
}
