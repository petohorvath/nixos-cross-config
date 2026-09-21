{
  coreutils,
  flakeParts,
  gnugrep,
  lib,
  nix,
  nixpkgs,
  runCommand,
  system,
}:
let
  expressionPath = import ./helpers/mk-failure-expression.nix {
    inherit flakeParts nixpkgs system;
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
    flakeMissingPaths = missingSetting "optionPaths";
    flakeInvalidCollection = invalidSetting "nodeCollection";
    flakeConflictingCollections = [
      "crossConfig.nodeCollection"
      "multiple times"
    ];
    flakeInvalidPaths = invalidSetting "optionPaths";
    flakeInvalidPath = invalidSetting "optionPaths";
    flakeInvalidSegment = invalidSetting "optionPaths";
    flakeEmptyRegistration = invalidSetting "optionPaths";
    flakeReservedCrossConfig = reservedRoot "crossConfig.nodes";
    flakeReservedModule = reservedRoot "_module.args";
    missingName = missingSetting "name";
    missingCollection = missingSetting "nodeCollection";
    missingPaths = missingSetting "optionPaths";
    invalidName = invalidSetting "name";
    invalidCollection = invalidSetting "nodeCollection";
    invalidPaths = invalidSetting "optionPaths";
    invalidPath = invalidSetting "optionPaths";
    invalidSegment = invalidSetting "optionPaths";
    conflictingCollections = [
      "crossConfig.nodeCollection"
      "multiple times"
    ];
    emptyRegistration = invalidSetting "optionPaths";
    reservedCrossConfig = reservedRoot "crossConfig.nodes" ++ [ "receiver" ];
    reservedModule = reservedRoot "_module.args" ++ [ "receiver" ];
    reservedWithoutName = [
      "crossConfig.optionPaths"
      "reserved root"
    ];
    legacyReservedCrossConfig = reservedRoot "crossConfig.nodes" ++ [ "receiver" ];
    legacyReservedModule = reservedRoot "_module.args" ++ [ "receiver" ];
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
  missingSetting = name: [
    "crossConfig.${name}"
    "was accessed but has no value defined"
  ];
  invalidSetting = name: [
    "crossConfig.${name}"
    "is not of type"
  ];
  reservedRoot = path: [
    "crossConfig.optionPaths"
    "reserved root"
    path
  ];
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
