{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      testRunner = pkgs.callPackage ../tests/runner.nix {
        inherit (inputs) nixpkgs;
        flakeParts = inputs.flake-parts;
        inherit system;
      };
    in
    {
      formatter = pkgs.callPackage ./formatter.nix { };
      devShells.default = pkgs.callPackage ./shell.nix {
        inherit (config) formatter;
        inherit testRunner;
      };
      checks = import ./checks.nix {
        inherit pkgs testRunner;
        inherit (config) formatter;
      };
    };
}
