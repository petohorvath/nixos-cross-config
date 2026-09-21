# Reconstruct development inputs from store paths for offline fixture evaluation.
{ flakePartsDir, nixpkgsDir }:
let
  inputs = {
    flakeParts = {
      outPath = flakePartsDir;
    }
    // (import (flakePartsDir + "/flake.nix")).outputs {
      self = inputs.flakeParts;
      nixpkgs-lib = inputs.nixpkgs;
    };
    nixpkgs = (import (nixpkgsDir + "/flake.nix")).outputs {
      self.outPath = nixpkgsDir;
    };
  };
in
inputs
