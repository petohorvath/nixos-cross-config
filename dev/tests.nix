# Load the nix-unit collection, using root inputs unless supplied explicitly.
{
  nixpkgs ? (builtins.getFlake (toString ../.)).inputs.nixpkgs,
  flakeParts ?
    (import ../tests/helpers/evaluation-inputs.nix {
      flakePartsDir = (builtins.getFlake (toString ../.)).inputs.flake-parts.outPath;
      nixpkgsDir = nixpkgs.outPath;
    }).flakeParts,
  system ? builtins.currentSystem,
}:
import ../tests {
  inherit flakeParts nixpkgs system;
}
