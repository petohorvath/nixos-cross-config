{
  description = "Configuration contributions between caller-owned NixOS nodes";

  inputs = {
    stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs:
    let
      development = import ./nix/development.nix {
        inherit (inputs) stable unstable;
        crossConfig.lib = { inherit mkModule; };
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
      lib = {
        inherit mkModule;
        inherit (development) failures tests;
      };
      inherit (development)
        checks
        devShells
        formatter
        nixosConfigurations
        ;
    };
}
