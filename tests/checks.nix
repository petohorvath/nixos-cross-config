{
  flakeParts,
  lib,
  nix-unit,
  nixpkgs,
  runCommand,
  system,
}:
let
  sourceDir = lib.cleanSource ../.;
  testEntrypoint = sourceDir + "/tests/entrypoint.nix";
  testSuites = import testEntrypoint { inherit flakeParts nixpkgs system; };
  testGroups = lib.concatLists (lib.mapAttrsToList groupsForSuite testSuites);

  # Select immediate suite entries; nix-unit discovers any nested tests.
  groupsForSuite =
    suiteName: suite:
    map (
      entryName:
      lib.showAttrPath [
        suiteName
        entryName
      ]
    ) (builtins.attrNames suite);

  # Reconstruct inputs from store paths so the sandbox needs no flake fetching.
  evaluationInputsFile = builtins.toFile "cross-config-test-inputs.nix" ''
    import ${sourceDir}/tests/helpers/evaluation-inputs.nix {
      flakePartsDir = "${flakeParts}";
      nixpkgsDir = "${nixpkgs}";
    }
  '';
in
assert testGroups != [ ];
runCommand "cross-config-tests" { nativeBuildInputs = [ nix-unit ]; } ''
  # Use a fresh evaluator per group to bound memory. The writable store lets
  # NixOS evaluation create derivations inside the build sandbox.
  for group in ${lib.escapeShellArgs testGroups}; do
    nix-unit --show-trace \
      --eval-store "$TMPDIR/eval-store" --gc-roots-dir "$TMPDIR/gc-roots" \
      ${testEntrypoint} --attr "$group" \
      --arg nixpkgs '(import ${evaluationInputsFile}).nixpkgs' \
      --arg flakeParts '(import ${evaluationInputsFile}).flakeParts' \
      --argstr system ${lib.escapeShellArg system}
  done

  touch "$out"
''
