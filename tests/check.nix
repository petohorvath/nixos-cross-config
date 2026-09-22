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
  testFile = sourceDir + "/dev/tests.nix";
  tests = import testFile { inherit flakeParts nixpkgs system; };
  # Bound memory by starting a fresh evaluator for each suite entry.
  groups = lib.concatLists (
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
  inputsPath = builtins.toFile "cross-config-test-inputs.nix" ''
    import ${sourceDir}/tests/helpers/evaluation-inputs.nix {
      flakePartsDir = "${flakeParts}";
      nixpkgsDir = "${nixpkgs}";
    }
  '';
  checkGroup = group: ''
    nix-unit --show-trace \
      --eval-store "$TMPDIR/eval-store" --gc-roots-dir "$TMPDIR/gc-roots" \
      ${testFile} --attr ${lib.escapeShellArg group} \
      --arg nixpkgs '(import ${inputsPath}).nixpkgs' \
      --arg flakeParts '(import ${inputsPath}).flakeParts' \
      --argstr system ${lib.escapeShellArg system}
  '';
in
assert groups != [ ];
runCommand "cross-config-tests" { nativeBuildInputs = [ nix-unit ]; } ''
  ${lib.concatMapStringsSep "\n" checkGroup groups}
  touch "$out"
''
