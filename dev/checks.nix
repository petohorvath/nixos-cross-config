{
  formatter,
  inputs,
  pkgs,
  system,
}:
let
  checks = {
    tests = pkgs.callPackage ../tests/check.nix {
      inherit (inputs) nixpkgs;
      flakeParts = inputs.flake-parts;
      inherit system;
    };
    formatting = mkCheck {
      name = "cross-config-formatting";
      packages = [ formatter ];
      script = "cross-config-fmt --ci";
    };
    lint = mkCheck {
      name = "cross-config-lint";
      packages = [
        pkgs.statix
        pkgs.deadnix
        pkgs.actionlint
      ];
      script = ''
        statix check .
        deadnix --fail .
        actionlint .github/workflows/*.yml
      '';
    };
  };
  mkCheck =
    {
      name,
      packages,
      script,
    }:
    pkgs.runCommand name { nativeBuildInputs = packages; } ''
      cp -R ${sourceDir} source
      chmod -R u+w source
      cd source
      ${script}
      touch "$out"
    '';
  sourceDir = pkgs.lib.cleanSource ../.;
in
checks
