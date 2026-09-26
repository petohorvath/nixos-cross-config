/*
  Load test definitions for nix-unit; nix-unit checks their expectations.
  Example: nix-unit tests/entrypoint.nix --attr merging
*/
let
  rootInputs = (builtins.getFlake (toString ../.)).inputs;

  # Use the selected nixpkgs for flake-parts too, including caller overrides.
  flakePartsFor =
    nixpkgs:
    (import ./helpers/evaluation-inputs.nix {
      flakePartsDir = rootInputs.flake-parts.outPath;
      nixpkgsDir = nixpkgs.outPath;
    }).flakeParts;
in
# Direct runs use these defaults. The flake check supplies all three arguments,
# so it does not need to load the root flake here.
{
  nixpkgs ? rootInputs.nixpkgs,
  flakeParts ? flakePartsFor nixpkgs,
  system ? builtins.currentSystem,
}:
let
  mkTestContext =
    crossConfig:
    import ./helpers/test-context.nix {
      inherit
        crossConfig
        flakeParts
        nixpkgs
        system
        ;
    };
  plainTestContext = mkTestContext (import ./helpers/plain-exports.nix);
  testContext =
    mkTestContext (
      import ./helpers/flake-outputs.nix {
        inherit flakeParts nixpkgs;
      }
    )
    // {
      plainFlakeConsumer = plainTestContext.flakeConsumer;
    };
in
import ./suites { inherit plainTestContext testContext; }
