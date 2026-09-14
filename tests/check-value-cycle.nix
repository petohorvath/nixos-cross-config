{
  nixpkgs,
  pkgs,
  system,
}:
let
  expression = builtins.toFile "cross-config-value-cycle.nix" ''
    let
      crossConfig = (import ${../.}/flake.nix).outputs { };
      nixpkgs = (import ${nixpkgs}/flake.nix).outputs {
        self.outPath = "${nixpkgs}";
      };
      mkNodes = import ${./mk-nodes.nix} {
        inherit crossConfig nixpkgs;
        system = "${system}";
      };
    in
    import ${./value-cycle.nix} { inherit mkNodes; }
  '';
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
