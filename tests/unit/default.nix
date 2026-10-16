# Unit suites for nix-unit. Run them locally with the root flake's locked
# inputs: nix-unit tests/unit --attr settings
let
  rootInputs = (builtins.getFlake (toString ../..)).inputs;
in
{
  nixpkgs ? rootInputs.nixpkgs,
  system ? builtins.currentSystem,
}:
let
  testContext = import ../test-context.nix { inherit nixpkgs system; };
in
{
  lib = import ./lib.nix testContext;
  nixos = {
    module = import ./nixos/module.nix testContext;
  };
  settings = import ./settings.nix testContext;
  tagged-destinations = import ./tagged-destinations.nix testContext;
}
