/*
  Assemble the public flake with the supplied inputs, including in offline
  runners.
*/
{ flakeParts, nixpkgs }:
let
  inputs = {
    flake-parts = flakeParts;
    inherit nixpkgs;
  };
  self = (import ../../flake.nix).outputs (inputs // { inherit self; }) // {
    outPath = ../..;
    inherit inputs;
  };
in
self
