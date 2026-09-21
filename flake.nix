{
  description = "Configuration contributions between caller-owned NixOS nodes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    inputs:
    let
      inherit (inputs) nixpkgs;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forSystems = nixpkgs.lib.genAttrs systems;
      development = forSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          formatter = pkgs.callPackage ./formatter.nix { };
        in
        {
          inherit formatter;
          shell = pkgs.callPackage ./shell.nix { inherit formatter; };
          checks = import ./tests/checks.nix {
            inherit
              formatter
              nixpkgs
              pkgs
              system
              ;
          };
        }
      );
      crossConfig = {
        lib = { inherit mkModule; };
        nixosModules.default = ./lib/module.nix;
      };

      mkModule =
        {
          name,
          nodes,
          optionPaths,
        }:
        { lib, ... }:
        # Use the receiver's lib for importApply-compatible source attribution.
        lib.setDefaultModuleLocation ./lib/mk-module.nix (
          import ./lib/mk-module.nix { inherit name nodes optionPaths; }
        );
    in
    {
      inherit (crossConfig) nixosModules;
      lib = {
        inherit mkModule;
        tests = forSystems (
          system:
          import ./tests {
            inherit crossConfig nixpkgs system;
          }
        );
        failures = forSystems (
          system:
          let
            mkNodes = import ./tests/mk-nodes.nix {
              inherit crossConfig nixpkgs system;
            };
          in
          import ./tests/failures.nix { inherit crossConfig mkNodes nixpkgs; }
          // {
            valueCycle = import ./tests/value-cycle.nix { inherit mkNodes; };
            taggedValueCycle = import ./tests/tagged-value-cycle.nix { inherit mkNodes; };
          }
        );
      };
      devShells = forSystems (system: {
        default = development.${system}.shell;
      });
      formatter = forSystems (system: development.${system}.formatter);
      packages = forSystems (system: {
        cross-config-fmt = development.${system}.formatter;
      });
      checks = forSystems (system: development.${system}.checks);
      nixosConfigurations = import ./examples/minimal.nix {
        inherit crossConfig nixpkgs;
      };
    };
}
