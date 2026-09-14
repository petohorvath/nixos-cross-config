{
  crossConfig,
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
  failures = import ./failures.nix { inherit mkNodes; };
in
{
  example = import ./example.nix { inherit crossConfig nixpkgs system; };
  forwarding = import ./forwarding.nix { inherit checkAssertions mkNodes; };
  hostGuest = import ./host-guest.nix { inherit checkAssertions crossConfig mkNodes; };
  literalPath = import ./literal-path.nix { inherit checkAssertions mkNodes; };
  merging = import ./merging.nix { inherit checkAssertions mkNodes; };
  nestedProperties = import ./nested-properties.nix { inherit checkAssertions mkNodes; };
  ordering = import ./ordering.nix { inherit checkAssertions mkNodes; };
  priorities = import ./priorities.nix { inherit checkAssertions mkNodes; };
  transportProperties = import ./transport-properties.nix { inherit checkAssertions mkNodes; };
  validation = builtins.mapAttrs (
    _: value:
    assert !(builtins.tryEval (builtins.deepSeq value true)).success;
    true
  ) failures;
}
