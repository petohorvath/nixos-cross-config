# Integration suites for nix-unit, evaluated through NixOS and flake-parts.
# Run them locally with the root flake's locked inputs:
# nix-unit tests/integration --attr merging
let
  rootInputs = (builtins.getFlake (toString ../..)).inputs;
  rebuild = import ../helpers/evaluation-inputs.nix;
in
{
  nixpkgs ? rootInputs.nixpkgs,
  # flake-parts follows nixpkgs, so rebuild it against the selected one.
  flake-parts ? rebuild {
    path = rootInputs.flake-parts.outPath;
    inputs.nixpkgs-lib = nixpkgs;
  },
  system ? builtins.currentSystem,
}:
let
  testContext = import ../test-context.nix { inherit flake-parts nixpkgs system; };
in
{
  conditional = import ./conditional.nix testContext;
  destinations = import ./destinations.nix testContext;
  example = import ./example.nix testContext;
  flake-module = import ./flake-module.nix testContext;
  flake-outputs = import ./flake-outputs.nix testContext;
  forwarding = import ./forwarding.nix testContext;
  host-guest = import ./host-guest.nix testContext;
  literal-path = import ./literal-path.nix testContext;
  merging = import ./merging.nix testContext;
  nested-properties = import ./nested-properties.nix testContext;
  ordering = import ./ordering.nix testContext;
  priorities = import ./priorities.nix testContext;
  reciprocal = import ./reciprocal.nix testContext;
  self-target = import ./self-target.nix testContext;
  sender-context = import ./sender-context.nix testContext;
  tagged-destinations = import ./tagged-destinations.nix testContext;
  transport-properties = import ./transport-properties.nix testContext;
}
