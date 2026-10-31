{ fixtures, helpers, ... }:
let
  inherit (fixtures) agreementRejections;
  inherit (helpers) allAssertionsPass messagePattern mkNodeCollection;
  hostsPath = [
    "networking"
    "hosts"
  ];
  domainPath = [
    "networking"
    "domain"
  ];
  contribution.crossConfig.contributions.receiver.networking.hosts."192.0.2.10" = [
    "sender.example"
  ];

  reorderedNodes = mkNodeCollection {
    optionPaths = [
      hostsPath
      domainPath
    ];
    modules = {
      sender = contribution;
      receiver =
        { lib, ... }:
        {
          crossConfig.optionPaths = lib.mkForce [
            domainPath
            hostsPath
          ];
        };
    };
  };
  plainEntryNodes = mkNodeCollection {
    optionPaths = [ hostsPath ];
    modules = {
      sender = contribution;
      receiver = { };
    };
    extraNodes.plain.config = { };
  };
in
{
  testReorderedPathsHosts = {
    expr = reorderedNodes.receiver.config.networking.hosts."192.0.2.10";
    expected = [ "sender.example" ];
  };
  testReorderedPathsAssertions = {
    expr = allAssertionsPass reorderedNodes;
    expected = true;
  };
  testPlainEntryHosts = {
    expr = plainEntryNodes.receiver.config.networking.hosts."192.0.2.10";
    expected = [ "sender.example" ];
  };
  testPlainEntryAssertions = {
    expr = allAssertionsPass { inherit (plainEntryNodes) receiver sender; };
    expected = true;
  };
  testRejectsDifferentPathsOnSender = {
    expr = agreementRejections.differentPathsSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "node `sender` and collection entry `receiver` disagree on shared settings"
        "Only `sender` allows `networking.hosts`."
      ];
    };
  };
  testRejectsDifferentPathsOnReceiver = {
    expr = agreementRejections.differentPathsReceiver;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "node `receiver` and collection entry `sender` disagree on shared settings"
        "Only `sender` allows `networking.hosts`."
      ];
    };
  };
  testRejectsIdleReceiverOnSender = {
    expr = agreementRejections.idleReceiverSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "node `sender` and collection entry `receiver` disagree on shared settings"
        "Only `sender` allows `networking.hosts`, `networking.domain`."
      ];
    };
  };
  testRejectsMissingSender = {
    expr = agreementRejections.missingSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "node `sender` and collection entry `receiver` disagree on shared settings"
        "Only the collection of `sender` contains `sender`."
      ];
    };
  };
  testRejectsRenamedSender = {
    expr = agreementRejections.renamedSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "node `renamed` is missing from its own crossConfig.nodeConfigurations."
      ];
    };
  };
  testRejectsRenamedSenderOnReceiver = {
    expr = agreementRejections.renamedSenderReceiver;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "node `receiver` and collection entry `sender` disagree on shared settings"
        "Its crossConfig.name is `renamed`."
      ];
    };
  };
  testRejectsPlainReceiver = {
    expr = agreementRejections.plainReceiver;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "sender `sender` targets receiver `plain`, which does not import the module."
      ];
    };
  };
}
