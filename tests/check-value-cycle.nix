{
  coreutils,
  gnugrep,
  nix,
  nixpkgs,
  runCommand,
  system,
}:
let
  checkCycle =
    fixtureName:
    let
      expressionPath = import ./mk-failure-expression.nix {
        inherit fixtureName nixpkgs system;
      };
    in
    ''
      if nix eval --extra-experimental-features nix-command --offline \
        --read-only --json --store dummy:// --file ${expressionPath} >result.json 2>error.log; then
        echo "Expected ${fixtureName} to fail with a value-dependency cycle." >&2
        cat result.json >&2
        exit 1
      fi
      cat error.log
      grep -F "error: infinite recursion encountered" error.log
    '';
in
# Native recursion errors escape tryEval, so inspect a separate evaluator.
runCommand "cross-config-value-cycle"
  {
    nativeBuildInputs = [
      coreutils
      gnugrep
      nix
    ];
  }
  ''
    ${checkCycle "value-cycle.nix"}
    ${checkCycle "tagged-value-cycle.nix"}
    touch "$out"
  ''
