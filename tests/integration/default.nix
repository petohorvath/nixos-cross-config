{
  flake-parts,
  nixpkgs,
  self,
  system,
}:
let
  testContext = import ../test-context.nix {
    inherit
      flake-parts
      nixpkgs
      self
      system
      ;
  };
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
