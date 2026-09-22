{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      formatter = pkgs.callPackage ./formatter.nix { };
      devShells.default = pkgs.callPackage ./shell.nix { inherit (config) formatter; };
      checks = import ./checks.nix {
        inherit (inputs) nixpkgs;
        flakeParts = inputs.flake-parts;
        inherit pkgs system;
        inherit (config) formatter;
      };
    };
}
