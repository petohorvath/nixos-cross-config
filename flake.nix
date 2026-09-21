{
  description = "Configuration contributions between caller-owned NixOS nodes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.flake-parts = {
    url = "github:hercules-ci/flake-parts";
    inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs =
    inputs:
    let
      inherit (inputs) nixpkgs;
      flakeParts = inputs.flake-parts;
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
              flakeParts
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
        nixosModules.default = ./nixos/module.nix;
        flakeModules.default = ./flake-module.nix;
      };

      mkModule =
        {
          name,
          nodes,
          optionPaths,
        }:
        { lib, ... }:
        # Use the receiver's lib for importApply-compatible source attribution.
        lib.setDefaultModuleLocation ./nixos/mk-module.nix (
          import ./nixos/mk-module.nix { inherit name nodes optionPaths; }
        );
    in
    {
      inherit (crossConfig) flakeModules nixosModules;
      lib = {
        inherit mkModule;
        tests = forSystems (
          system:
          import ./tests {
            inherit
              crossConfig
              flakeParts
              nixpkgs
              system
              ;
          }
        );
        failures = forSystems (
          system:
          let
            mkNodes = import ./tests/helpers/mk-nodes.nix {
              inherit crossConfig nixpkgs system;
            };
          in
          import ./tests/failures.nix {
            inherit
              crossConfig
              flakeParts
              mkNodes
              nixpkgs
              ;
          }
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
