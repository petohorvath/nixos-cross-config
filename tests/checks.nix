{
  formatter,
  nixpkgsInputs,
  pkgs,
  system,
}:
let
  checks =
    builtins.mapAttrs (
      _: nixpkgs:
      pkgs.callPackage ./check-evaluation.nix {
        inherit nixpkgs system;
      }
    ) nixpkgsInputs
    // pkgs.lib.mapAttrs' (
      channel: nixpkgs:
      pkgs.lib.nameValuePair "${channel}-value-cycle" (
        pkgs.callPackage ./check-value-cycle.nix {
          inherit nixpkgs system;
        }
      )
    ) nixpkgsInputs
    // pkgs.lib.mapAttrs' (
      channel: nixpkgs:
      pkgs.lib.nameValuePair "${channel}-diagnostics" (
        pkgs.callPackage ./check-diagnostics.nix {
          inherit nixpkgs system;
        }
      )
    ) nixpkgsInputs
    // {
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
