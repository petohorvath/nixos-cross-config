{
  collections,
  pkgs,
  system,
}:
let
  checks =
    builtins.mapAttrs (
      _: nixpkgs:
      pkgs.callPackage ../tests/check-evaluation.nix {
        inherit nixpkgs system;
      }
    ) collections
    // pkgs.lib.mapAttrs' (
      channel: nixpkgs:
      pkgs.lib.nameValuePair "${channel}-value-cycle" (
        pkgs.callPackage ../tests/check-value-cycle.nix {
          inherit nixpkgs system;
        }
      )
    ) collections
    // pkgs.lib.mapAttrs' (
      channel: nixpkgs:
      pkgs.lib.nameValuePair "${channel}-diagnostics" (
        pkgs.callPackage ../tests/check-diagnostics.nix {
          inherit nixpkgs system;
        }
      )
    ) collections
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
  formatter = pkgs.callPackage ./formatter.nix { };
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
{
  inherit checks formatter;
  shell = pkgs.mkShellNoCC {
    packages = [
      pkgs.nix
      pkgs.nil
      pkgs.nixfmt
      pkgs.statix
      pkgs.deadnix
      pkgs.git
      pkgs.shfmt
      pkgs.prettier
      pkgs.actionlint
      formatter
    ];
  };
}
