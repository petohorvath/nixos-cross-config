{
  crossConfig,
  flakeParts,
  nixpkgs,
  system,
}:
let
  messagePattern = import ./helpers/message-pattern.nix { inherit (nixpkgs) lib; };
  checkAssertions =
    nodes:
    nixpkgs.lib.pipe nodes [
      builtins.attrValues
      (builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions))
    ];
  mkNodes = import ./helpers/mk-nodes.nix {
    inherit crossConfig nixpkgs system;
  };
in
{
  conditional = import ./conditional.nix { inherit checkAssertions mkNodes; };
  destinations = import ./destinations.nix { inherit checkAssertions messagePattern mkNodes; };
  example = import ./example.nix { inherit crossConfig nixpkgs system; };
  forwarding = import ./forwarding.nix { inherit checkAssertions messagePattern mkNodes; };
  flakeModule = import ./flake-module.nix {
    inherit
      checkAssertions
      crossConfig
      flakeParts
      messagePattern
      nixpkgs
      system
      ;
  };
  hostGuest = import ./host-guest.nix { inherit checkAssertions crossConfig mkNodes; };
  literalPath = import ./literal-path.nix { inherit checkAssertions mkNodes; };
  merging = import ./merging.nix { inherit checkAssertions messagePattern mkNodes; };
  mkModule = import ./mk-module.nix { inherit crossConfig nixpkgs; };
  module = import ./module.nix { inherit crossConfig nixpkgs; };
  moduleSettings = import ./module-settings.nix { inherit crossConfig messagePattern nixpkgs; };
  nestedProperties = import ./nested-properties.nix {
    inherit checkAssertions messagePattern mkNodes;
  };
  ordering = import ./ordering.nix { inherit checkAssertions mkNodes; };
  plainImports =
    let
      crossConfig = {
        lib = import ../lib;
        nixosModules.default = ../nixos/module.nix;
      };
    in
    {
      mkModule = import ./mk-module.nix { inherit crossConfig nixpkgs; };
      module = import ./module.nix { inherit crossConfig nixpkgs; };
    };
  priorities = import ./priorities.nix { inherit checkAssertions messagePattern mkNodes; };
  reciprocal = import ./reciprocal.nix { inherit checkAssertions mkNodes; };
  selfTarget = import ./self-target.nix { inherit checkAssertions mkNodes; };
  senderContext = import ./sender-context.nix { inherit checkAssertions mkNodes; };
  transportProperties = import ./transport-properties.nix { inherit checkAssertions mkNodes; };
  taggedDestinations = import ./tagged-destinations.nix {
    inherit
      checkAssertions
      crossConfig
      messagePattern
      nixpkgs
      system
      ;
  };
}
