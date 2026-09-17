{
  jq,
  lib,
  nix,
  nixpkgs,
  runCommand,
  system,
}:
let
  crossConfig = (import ../flake.nix).outputs { };
  tests = import ./. { inherit crossConfig nixpkgs system; };
  fixturePaths =
    map (name: [ name ]) (lib.remove "validation" (builtins.attrNames tests))
    ++ map (name: [
      "validation"
      name
    ]) (builtins.attrNames tests.validation);
  expressionPath = builtins.toFile "cross-config-evaluation" ''
    let
      crossConfig = (import ${../.}/flake.nix).outputs { };
      nixpkgs = (import ${nixpkgs}/flake.nix).outputs {
        self.outPath = "${nixpkgs}";
      };
    in
    import ${../.}/tests {
      inherit crossConfig nixpkgs;
      system = "${system}";
    }
  '';
  checkFixture = index: path: ''
    echo ${lib.escapeShellArg "Checking ${lib.concatStringsSep "." path}"}
    nix eval --extra-experimental-features nix-command --offline \
      --read-only --json --store dummy:// --file ${expressionPath} \
      ${lib.escapeShellArg (lib.concatStringsSep "." path)} > value.json
    jq --argjson path ${lib.escapeShellArg (builtins.toJSON path)} \
      '. as $value | {} | setpath($path; $value)' value.json > result-${toString index}.json
  '';
in
# Separate evaluators bound memory while retaining the focused fixture results.
runCommand "cross-config-evaluation-tests.json"
  {
    nativeBuildInputs = [
      jq
      nix
    ];
  }
  ''
    ${lib.concatStringsSep "\n" (lib.imap0 checkFixture fixturePaths)}
    jq -s 'reduce .[] as $result ({}; . * $result)' result-*.json > "$out"
  ''
