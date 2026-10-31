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
  idleNodes = mkNodeCollection {
    optionPaths = [ ];
    modules.idle = { };
    extraNodes.unused = throw "An idle node forced a collection entry.";
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
    expr = agreementRejections.differentPathsOnSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "nodes `sender` and `receiver` disagree on shared settings"
        "Only `sender` allows `networking.hosts`."
      ];
    };
  };
  testRejectsDifferentPathsOnReceiver = {
    expr = agreementRejections.differentPathsOnReceiver;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "nodes `receiver` and `sender` disagree on shared settings"
        "Only `sender` allows `networking.hosts`."
      ];
    };
  };
  testRejectsIdleReceiverOnSender = {
    expr = agreementRejections.idleReceiverOnSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "nodes `sender` and `receiver` disagree on shared settings"
        "Only `sender` allows `networking.hosts`, `networking.domain`."
      ];
    };
  };
  testRejectsExcludedSenderOnSender = {
    expr = agreementRejections.excludedSenderOnSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "nodes `sender` and `receiver` disagree on shared settings"
        "Only the collection of `sender` contains `sender`."
      ];
    };
  };
  testRejectsRenamedSenderOnSender = {
    expr = agreementRejections.renamedSenderOnSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "node `renamed` is missing from its own crossConfig.nodeConfigurations."
      ];
    };
  };
  testRejectsRenamedSenderOnReceiver = {
    expr = agreementRejections.renamedSenderOnReceiver;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "nodes `receiver` and `sender` disagree on shared settings"
        "Collection key `sender` holds node `renamed`."
      ];
    };
  };
  testRejectsIdleSenderOnSender = {
    expr = agreementRejections.idleSenderOnSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "nodes `sender` and `receiver` disagree on shared settings"
        "Only `receiver` allows `networking.hosts`, `networking.domain`."
      ];
    };
  };
  testIdleNodeLeavesCollectionUnforced = {
    expr = allAssertionsPass { inherit (idleNodes) idle; };
    expected = true;
  };
  testRejectsPlainReceiverOnSender = {
    expr = agreementRejections.plainReceiverOnSender;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "sender `sender` targets receiver `plain`, which does not import the module."
      ];
    };
  };
}
