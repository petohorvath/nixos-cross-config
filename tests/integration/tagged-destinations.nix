{ fixtures, helpers, ... }:
let
  inherit (fixtures) taggedNixos taggedRejections taggedValueCycle;
  inherit (helpers) messagePattern;

  contributionOrigin = [
    "sender `sender`"
    "receiver `receiver`"
    "destination `inventory.payload.value`"
    "fixtures/tagged-destinations.nix"
  ];
in
{
  nixos = {
    testPublication = {
      expr = taggedNixos.publication;
      expected = {
        domain = "application.example";
        upstream = "http://192.0.2.10:8080";
      };
    };
    testProxyPass = {
      expr = taggedNixos.proxyPass;
      expected = "http://192.0.2.10:8080";
    };
    testFirewallPort = {
      expr = builtins.elem 80 taggedNixos.firewallPorts;
      expected = true;
    };
    testAssertions = {
      expr = builtins.all (builtins.all (value: value)) (builtins.attrValues taggedNixos.assertions);
      expected = true;
    };
  };
  testRejectsConflict = {
    expr = taggedRejections.conflict;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "conflicting definition" ] ++ contributionOrigin);
    };
  };
  testRejectsDefaultSource = {
    expr = taggedRejections.defaultSource;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "is not of type"
        "inventory.payload"
        "fixtures/tagged-default.nix"
      ];
    };
  };
  testRejectsIncompatible = {
    expr = taggedRejections.incompatible;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "is not of type" ] ++ contributionOrigin);
    };
  };
  testRejectsInspectionDefinitionSource = {
    expr = taggedRejections.inspectionDefinitionSource;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern [
        "is not of type"
        "inventory.payload.locked"
        "fixtures/tagged-invalid-local.nix"
      ];
    };
  };
  testRejectsMissingChild = {
    expr = taggedRejections.missingChild;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "missing destination" ] ++ contributionOrigin);
    };
  };
  testRejectsMissingTag = {
    expr = taggedRejections.missingTag;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "missing destination" ] ++ contributionOrigin);
    };
  };
  testRejectsReadOnlyChild = {
    expr = taggedRejections.readOnlyChild;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "read-only destination" ] ++ contributionOrigin);
    };
  };
  testRejectsReadOnlyCoerced = {
    expr = taggedRejections.readOnlyCoerced;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "read-only destination" ] ++ contributionOrigin);
    };
  };
  testRejectsReadOnlyEither = {
    expr = taggedRejections.readOnlyEither;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "read-only destination" ] ++ contributionOrigin);
    };
  };
  testRejectsReadOnlyLocal = {
    expr = taggedRejections.readOnlyLocal;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "read-only destination" ] ++ contributionOrigin);
    };
  };
  testRejectsReadOnlyName = {
    expr = taggedRejections.readOnlyName;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "read-only destination" ] ++ contributionOrigin);
    };
  };
  testRejectsReadOnlyNullable = {
    expr = taggedRejections.readOnlyNullable;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "read-only destination" ] ++ contributionOrigin);
    };
  };
  testRejectsReadOnlyTag = {
    expr = taggedRejections.readOnlyTag;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "read-only destination" ] ++ contributionOrigin);
    };
  };
  testRejectsReadOnlyUnique = {
    expr = taggedRejections.readOnlyUnique;
    expectedError = {
      type = "ThrownError";
      msg = messagePattern ([ "read-only destination" ] ++ contributionOrigin);
    };
  };
  testRejectsValueCycle = {
    expr = taggedValueCycle;
    expectedError = {
      type = "EvalError";
      msg = "infinite recursion encountered";
    };
  };
}
