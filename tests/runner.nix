{
  coreutils,
  flakeParts,
  jq,
  lib,
  nix,
  nix-unit,
  nixpkgs,
  system,
  writeShellApplication,
}:
let
  inputsPath = builtins.toFile "cross-config-test-inputs.nix" ''
    import ${./helpers/evaluation-inputs.nix} {
      flakePartsDir = "${flakeParts}";
      nixpkgsDir = "${nixpkgs}";
    }
  '';
in
writeShellApplication {
  name = "cross-config-test";
  runtimeInputs = [
    coreutils
    jq
    nix
    nix-unit
  ];
  text = ''
    readonly inputsPath=${inputsPath}
    readonly system=${lib.escapeShellArg system}
    readonly manifestPath=${./helpers/test-manifest.nix}
    ${builtins.readFile ./run.sh}
  '';
}
