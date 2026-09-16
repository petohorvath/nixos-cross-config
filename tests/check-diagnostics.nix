{
  nixpkgs,
  pkgs,
  system,
}:
let
  inherit (pkgs) lib;
  expression = import ./mk-failure-expression.nix {
    inherit nixpkgs system;
    fixture = "failures.nix";
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
    if nix-instantiate --eval --strict --json --show-trace --store dummy:// \
      ${expression} --attr ${name} >result.json 2>error.log; then
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
pkgs.runCommand "cross-config-diagnostics" { nativeBuildInputs = [ pkgs.nix ]; } ''
  ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkCheck cases)}
  touch "$out"
''
