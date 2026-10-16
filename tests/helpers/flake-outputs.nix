# Assemble the public flake with the supplied inputs, including in offline
# runners.
{ flake-parts, nixpkgs }:
let
  inputs = { inherit flake-parts nixpkgs; };
  self = (import ../../flake.nix).outputs (inputs // { inherit self; }) // {
    outPath = ../..;
    inherit inputs;
  };
in
self
