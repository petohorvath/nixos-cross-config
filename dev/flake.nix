{
  description = "Development and public evaluation tests for nixos-cross-config";

  inputs = {
    stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { stable, unstable, ... }:
    let
      crossConfig = (import ../flake.nix).outputs { };
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = stable.lib.genAttrs systems;
      collections = { inherit stable unstable; };
      testResults = forAllSystems (
        system:
        builtins.mapAttrs (
          _: nixpkgs:
          import ../tests {
            inherit crossConfig nixpkgs system;
          }
        ) collections
      );
    in
    {
      formatter = forAllSystems (system: stable.legacyPackages.${system}.nixfmt-tree);

      lib.tests = testResults;
      lib.failures = forAllSystems (
        system:
        builtins.mapAttrs (
          _: nixpkgs:
          import ../tests/failures.nix {
            mkNodes = import ../tests/mk-nodes.nix {
              inherit crossConfig nixpkgs system;
            };
          }
        ) collections
      );

      checks = forAllSystems (
        system:
        let
          pkgs = stable.legacyPackages.${system};
          nixFileArguments = stable.lib.pipe ../. [
            stable.lib.filesystem.listFilesRecursive
            (builtins.filter (stable.lib.hasSuffix ".nix"))
            (map (file: stable.lib.removePrefix "${toString ../.}/" (toString file)))
            stable.lib.escapeShellArgs
          ];
        in
        builtins.mapAttrs (
          channel: results: pkgs.writeText "cross-config-${channel}-tests.json" (builtins.toJSON results)
        ) testResults.${system}
        // {
          formatting =
            pkgs.runCommand "cross-config-formatting"
              {
                nativeBuildInputs = [ pkgs.nixfmt ];
                src = ../.;
              }
              ''
                cd "$src"
                nixfmt --check ${nixFileArguments}
                touch "$out"
              '';
        }
      );

      nixosConfigurations = import ../examples/minimal.nix {
        inherit crossConfig;
        nixpkgs = stable;
      };
    };
}
