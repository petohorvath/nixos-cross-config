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
  tests = import testEntrypoint { inherit flakeParts nixpkgs system; };
  # Bound memory by starting a fresh evaluator for each suite entry.
  testGroups = lib.concatLists (
    lib.mapAttrsToList (
      suite: entries:
      map (
        entry:
        lib.showAttrPath [
          suite
          entry
        ]
      ) (builtins.attrNames entries)
    ) tests
  );
  # Reconstruct inputs from store paths so the sandbox needs no flake fetching.
  evaluationInputsFile = builtins.toFile "cross-config-test-inputs.nix" ''
    import ${sourceDir}/tests/helpers/evaluation-inputs.nix {
      flakePartsDir = "${flakeParts}";
      nixpkgsDir = "${nixpkgs}";
    }
  '';
  # NixOS evaluation creates store paths, so each run needs a writable store.
  runTestGroup = group: ''
    nix-unit --show-trace \
      --eval-store "$TMPDIR/eval-store" --gc-roots-dir "$TMPDIR/gc-roots" \
      ${testEntrypoint} --attr ${lib.escapeShellArg group} \
      --arg nixpkgs '(import ${evaluationInputsFile}).nixpkgs' \
      --arg flakeParts '(import ${evaluationInputsFile}).flakeParts' \
      --argstr system ${lib.escapeShellArg system}
  '';
in
assert testGroups != [ ];
runCommand "cross-config-tests" { nativeBuildInputs = [ nix-unit ]; } ''
  ${lib.concatMapStringsSep "\n" runTestGroup testGroups}
  touch "$out"
''
