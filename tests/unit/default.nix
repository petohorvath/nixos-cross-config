{ nixpkgs, system }:
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
