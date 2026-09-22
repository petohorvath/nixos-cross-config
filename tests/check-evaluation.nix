{
  flakeParts,
  lib,
  nix-unit,
  nixpkgs,
  runCommand,
  system,
}:
let
  crossConfig = import ./helpers/flake-outputs.nix { inherit flakeParts nixpkgs; };
  tests = import ./. {
    inherit
      crossConfig
      flakeParts
      nixpkgs
      system
      ;
  };
  fixturePaths =
    map (name: [ name ]) (lib.subtractLists [ "flakeModule" "validation" ] (builtins.attrNames tests))
    ++ map (name: [
      "flakeModule"
      name
    ]) (builtins.attrNames tests.flakeModule)
    ++ map (name: [
      "validation"
      name
    ]) (builtins.attrNames tests.validation);
  expressionPath = builtins.toFile "cross-config-evaluation" ''
    let
      inherit (import ${./helpers/evaluation-inputs.nix} {
        flakePartsDir = "${flakeParts}";
        nixpkgsDir = "${nixpkgs}";
      }) flakeParts nixpkgs;
      crossConfig = import ${../.}/tests/helpers/flake-outputs.nix { inherit flakeParts nixpkgs; };
    in
    import ${../.}/tests {
      inherit crossConfig flakeParts nixpkgs;
      system = "${system}";
    }
  '';
  checkFixture = path: ''
    echo ${lib.escapeShellArg "Checking ${lib.concatStringsSep "." path}"}
    nix-unit --eval-store "$TMPDIR/eval-store" --gc-roots-dir "$TMPDIR/gc-roots" \
      ${expressionPath} \
      --attr ${lib.escapeShellArg (lib.concatStringsSep "." path)}
  '';
in
# Separate evaluators bound memory across NixOS fixtures.
runCommand "cross-config-evaluation-tests"
  {
    nativeBuildInputs = [ nix-unit ];
  }
  ''
    ${lib.concatMapStringsSep "\n" checkFixture fixturePaths}
    touch "$out"
  ''
