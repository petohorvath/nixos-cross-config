{
  crossConfig,
  nixpkgs,
  system,
}:
import ../../tests/fixtures/tagged-nixos.nix { inherit crossConfig nixpkgs system; }
