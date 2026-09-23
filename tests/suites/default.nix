{ plainTestContext, testContext }:
{
  conditional = import ./conditional.nix testContext;
  destinations = import ./destinations.nix testContext;
  example = import ./example.nix testContext;
  forwarding = import ./forwarding.nix testContext;
  flakeModule = import ./flake-module.nix testContext;
  hostGuest = import ./host-guest.nix testContext;
  literalPath = import ./literal-path.nix testContext;
  merging = import ./merging.nix testContext;
  mkModule = import ./mk-module.nix testContext;
  module = import ./module.nix testContext;
  moduleSettings = import ./module-settings.nix testContext;
  nestedProperties = import ./nested-properties.nix testContext;
  ordering = import ./ordering.nix testContext;
  plainImports = {
    mkModule = import ./mk-module.nix plainTestContext;
    module = import ./module.nix plainTestContext;
  };
  priorities = import ./priorities.nix testContext;
  reciprocal = import ./reciprocal.nix testContext;
  selfTarget = import ./self-target.nix testContext;
  senderContext = import ./sender-context.nix testContext;
  transportProperties = import ./transport-properties.nix testContext;
  taggedDestinations = import ./tagged-destinations.nix testContext;
}
