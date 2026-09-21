{
  flakeParts,
  lib,
  nix-unit,
  nixpkgs,
  runCommand,
  system,
}:
let
  checkCycle =
    fixtureName:
    let
      expressionPath = import ./helpers/mk-failure-expression.nix {
        inherit
          fixtureName
          flakeParts
          nixpkgs
          system
          ;
      };
    in
    ''
      echo ${lib.escapeShellArg "Checking ${fixtureName}"}
      nix-unit --eval-store "$TMPDIR/eval-store" --gc-roots-dir "$TMPDIR/gc-roots" \
        --expr ${lib.escapeShellArg ''
          {
            testCycle = {
              expr = builtins.deepSeq (import ${expressionPath}) true;
              expectedError = {
                type = "EvalError";
                msg = "infinite recursion encountered";
              };
            };
          }
        ''}
    '';
in
# nix-unit catches native recursion errors that escape builtins.tryEval.
runCommand "cross-config-value-cycle"
  {
    nativeBuildInputs = [ nix-unit ];
  }
  ''
    ${checkCycle "value-cycle.nix"}
    ${checkCycle "tagged-value-cycle.nix"}
    touch "$out"
  ''
