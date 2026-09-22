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
      development = flakeParts.lib.mkFlake { inherit inputs; } {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        imports = [
          (flakeParts.lib.importApply ./tests/flake-parts.nix { inherit crossConfig; })
        ];

        perSystem =
          { config, pkgs, ... }:
          {
            formatter = pkgs.callPackage ./formatter.nix { };
            packages.cross-config-fmt = config.formatter;
            devShells.default = pkgs.callPackage ./shell.nix { inherit (config) formatter; };
          };

        flake.nixosConfigurations = import ./examples/minimal.nix {
          inherit crossConfig nixpkgs;
        };
      };
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
      # Named exports keep plain imports independent of development inputs.
      inherit (crossConfig) flakeModules nixosModules;
      lib = {
        inherit mkModule;
        inherit (development.lib) failures tests;
      };
      inherit (development)
        checks
        devShells
        formatter
        nixosConfigurations
        packages
        ;
    };
}
