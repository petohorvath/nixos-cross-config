{
  description = "Configuration contributions between caller-owned NixOS nodes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forSystems = inputs.nixpkgs.lib.genAttrs systems;
      collections = {
        stable = inputs.nixpkgs;
        unstable = inputs.nixpkgs-unstable;
      };
      development = forSystems (
        system:
        import ./nix/development.nix {
          inherit collections system;
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        }
      );
      crossConfig.lib = { inherit mkModule; };

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
      lib = {
        inherit mkModule;
        tests = forSystems (
          system:
          builtins.mapAttrs (
            _: nixpkgs:
            import ./tests {
              inherit crossConfig nixpkgs system;
            }
          ) collections
        );
        failures = forSystems (
          system:
          builtins.mapAttrs (
            _: nixpkgs:
            let
              mkNodes = import ./tests/mk-nodes.nix {
                inherit crossConfig nixpkgs system;
              };
            in
            import ./tests/failures.nix { inherit mkNodes; }
            // {
              valueCycle = import ./tests/value-cycle.nix { inherit mkNodes; };
              taggedValueCycle = import ./tests/tagged-value-cycle.nix { inherit mkNodes; };
            }
          ) collections
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
        inherit crossConfig;
        inherit (inputs) nixpkgs;
      };
    };
}
