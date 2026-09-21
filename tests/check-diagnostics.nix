{
  coreutils,
  gnugrep,
  lib,
  nix,
  nixpkgs,
  runCommand,
  system,
}:
let
  expressionPath = import ./mk-failure-expression.nix {
    inherit nixpkgs system;
    fixtureName = "failures.nix";
  };
  origin = [
    "sender `sender`"
    "receiver `receiver`"
    "destination `inventory.value`"
    "fixtures/destination-sender.nix"
  ];
  taggedOrigin = [
    "sender `sender`"
    "receiver `receiver`"
    "destination `inventory.payload.value`"
    "tagged-failures.nix"
  ];
  cases = {
    missingName = [
      "crossConfig.name"
      "was accessed but has no value defined"
    ];
    missingCollection = [
      "crossConfig.nodeCollection"
      "was accessed but has no value defined"
    ];
    missingPaths = [
      "crossConfig.optionPaths"
      "was accessed but has no value defined"
    ];
    invalidName = [
      "crossConfig.name"
      "is not of type"
    ];
    invalidCollection = [
      "crossConfig.nodeCollection"
      "is not of type"
    ];
    invalidPaths = [
      "crossConfig.optionPaths"
      "is not of type"
    ];
    invalidPath = [
      "crossConfig.optionPaths"
      "is not of type"
    ];
    invalidSegment = [
      "crossConfig.optionPaths"
      "is not of type"
    ];
    conflictingCollections = [
      "crossConfig.nodeCollection"
      "multiple times"
    ];
    emptyRegistration = [
      "crossConfig.optionPaths"
      "is not of type"
    ];
    reservedCrossConfig = [
      "crossConfig.optionPaths"
      "reserved root"
      "crossConfig.nodes"
      "receiver"
    ];
    reservedModule = [
      "crossConfig.optionPaths"
      "reserved root"
      "_module.args"
      "receiver"
    ];
    reservedWithoutName = [
      "crossConfig.optionPaths"
      "reserved root"
    ];
    legacyReservedCrossConfig = [
      "crossConfig.optionPaths"
      "reserved root"
      "crossConfig.nodes"
      "receiver"
    ];
    legacyReservedModule = [
      "crossConfig.optionPaths"
      "reserved root"
      "_module.args"
      "receiver"
    ];
    taggedMissingTag = [ "missing destination" ] ++ taggedOrigin;
    taggedMissingChild = [ "missing destination" ] ++ taggedOrigin;
    taggedReadOnlyTag = [ "read-only destination" ] ++ taggedOrigin;
    taggedReadOnlyChild = [ "read-only destination" ] ++ taggedOrigin;
    taggedReadOnlyName = [ "read-only destination" ] ++ taggedOrigin;
    taggedReadOnlyLocal = [ "read-only destination" ] ++ taggedOrigin;
    taggedReadOnlyCoerced = [ "read-only destination" ] ++ taggedOrigin;
    taggedReadOnlyEither = [ "read-only destination" ] ++ taggedOrigin;
    taggedReadOnlyNullable = [ "read-only destination" ] ++ taggedOrigin;
    taggedReadOnlyUnique = [ "read-only destination" ] ++ taggedOrigin;
    taggedIncompatible = [ "is not of type" ] ++ taggedOrigin;
    taggedConflict = [ "conflicting definition" ] ++ taggedOrigin;
    taggedDefaultSource = [
      "is not of type"
      "inventory.payload"
      "fixtures/tagged-default.nix"
    ];
    taggedInspectionDefinitionSource = [
      "is not of type"
      "inventory.payload.locked"
      "fixtures/tagged-invalid-local.nix"
    ];
    missingDestination = [ "missing destination" ] ++ origin;
    missingSubmoduleDestination = [ "missing destination" ] ++ origin;
    readOnlyDestination = [ "read-only destination" ] ++ origin;
    readOnlyNamedDestination = [ "read-only destination" ] ++ origin;
    readOnlyLocalSubmoduleConfig = [ "read-only destination" ] ++ origin;
    readOnlyCoercedDestination = [ "read-only destination" ] ++ origin;
    readOnlyEitherDestination = [ "read-only destination" ] ++ origin;
    readOnlyNullableDestination = [ "read-only destination" ] ++ origin;
    readOnlyUniqueDestination = [ "read-only destination" ] ++ origin;
    readOnlyTaggedDestination = [ "read-only destination" ] ++ origin;
    readOnlySubmoduleDestination = [ "read-only destination" ] ++ origin;
    readOnlyDefault = [ "read-only destination" ] ++ origin;
    readOnlyLocal = [ "read-only destination" ] ++ origin;
    incompatibleDestination = [ "is not of type" ] ++ origin;
    conflictingDestination = [ "conflicting definition" ] ++ origin;
    senderConflict = [
      "conflicting definition"
      "sender `alpha`"
      "sender `beta`"
      "receiver `receiver`"
      "destination `networking.domain`"
    ];
    nestedConflict = [
      "conflicting definition"
      "sender `sender`"
      "receiver `receiver`"
      "destination `services.nginx.virtualHosts`"
      "proxyPass"
    ];
    unknownReceiver = [
      "sender `sender`"
      "unknown receiver `receiver`"
    ];
    unregisteredDestination = [
      "sender `sender`"
      "crossConfig.nodes.receiver.inventory"
      "does not exist"
      "fixtures/destination-sender.nix"
    ];
  };
  mkCheck = name: expected: ''
    if nix eval --extra-experimental-features nix-command --offline \
      --read-only --json --show-trace --store dummy:// \
      --file ${expressionPath} ${name} >result.json 2>error.log; then
      echo "Expected ${name} to fail evaluation." >&2
      cat result.json >&2
      exit 1
    fi
    ${lib.concatMapStringsSep "\n" (fragment: ''
      if ! grep -F -- ${lib.escapeShellArg fragment} error.log > /dev/null; then
        echo "Missing diagnostic context for ${name}:" >&2
        printf '%s\n' ${lib.escapeShellArg fragment} >&2
        cat error.log >&2
        exit 1
      fi
    '') expected}
  '';
in
runCommand "cross-config-diagnostics"
  {
    nativeBuildInputs = [
      coreutils
      gnugrep
      nix
    ];
  }
  ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkCheck cases)}
    touch "$out"
  ''
