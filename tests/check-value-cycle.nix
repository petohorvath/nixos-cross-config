{
  nixpkgs,
  pkgs,
  system,
}:
let
  expression = import ./mk-failure-expression.nix {
    inherit nixpkgs system;
    fixture = "value-cycle.nix";
  };
in
# Native recursion errors escape tryEval, so inspect a separate evaluator.
pkgs.runCommand "cross-config-value-cycle" { nativeBuildInputs = [ pkgs.nix ]; } ''
  if nix-instantiate --eval --strict --json --store dummy:// \
    ${expression} >result.json 2>error.log; then
    echo "Expected a value-dependency cycle to fail evaluation." >&2
    cat result.json >&2
    exit 1
  fi
  cat error.log
  grep -F "error: infinite recursion encountered" error.log
  touch "$out"
''
