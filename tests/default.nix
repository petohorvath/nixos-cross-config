{
  crossConfig,
  flakeParts,
  nixpkgs,
  system,
}:
let
  checkAssertions =
    nodes:
    nixpkgs.lib.pipe nodes [
      builtins.attrValues
      (builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions))
    ];
  mkNodes = import ./mk-nodes.nix {
    inherit crossConfig nixpkgs system;
  };
  failures = import ./failures.nix {
    inherit
      crossConfig
      flakeParts
      mkNodes
      nixpkgs
      ;
  };
in
{
  conditional = import ./conditional.nix { inherit checkAssertions mkNodes; };
  destinations = import ./destinations.nix { inherit checkAssertions mkNodes; };
  example = import ./example.nix { inherit crossConfig nixpkgs system; };
  forwarding = import ./forwarding.nix { inherit checkAssertions mkNodes; };
  flakeModule = import ./flake-module.nix {
    inherit
      checkAssertions
      crossConfig
      flakeParts
      nixpkgs
      system
      ;
  };
  hostGuest = import ./host-guest.nix { inherit checkAssertions crossConfig mkNodes; };
  literalPath = import ./literal-path.nix { inherit checkAssertions mkNodes; };
  merging = import ./merging.nix { inherit checkAssertions mkNodes; };
  mkModule = import ./mk-module.nix { inherit nixpkgs; };
  module = import ./module.nix { inherit nixpkgs; };
  moduleSettings = import ./module-settings.nix { inherit crossConfig nixpkgs; };
  nestedProperties = import ./nested-properties.nix { inherit checkAssertions mkNodes; };
  ordering = import ./ordering.nix { inherit checkAssertions mkNodes; };
  priorities = import ./priorities.nix { inherit checkAssertions mkNodes; };
  reciprocal = import ./reciprocal.nix { inherit checkAssertions mkNodes; };
  selfTarget = import ./self-target.nix { inherit checkAssertions mkNodes; };
  senderContext = import ./sender-context.nix { inherit checkAssertions mkNodes; };
  transportProperties = import ./transport-properties.nix { inherit checkAssertions mkNodes; };
  taggedDestinations = import ./tagged-destinations.nix {
    inherit
      checkAssertions
      crossConfig
      nixpkgs
      system
      ;
  };
  validation = builtins.mapAttrs (
    _: value:
    assert !(builtins.tryEval (builtins.deepSeq value true)).success;
    true
  ) failures;
}
