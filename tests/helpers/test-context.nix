{
  crossConfig,
  flakeParts,
  nixpkgs,
  system,
}:
let
  inherit (nixpkgs) lib;
  evaluation = import ./evaluate-module.nix { inherit crossConfig lib; };
  mkNodeCollection = import ./mk-node-collection.nix {
    inherit crossConfig lib system;
    inherit (evaluation) evaluateModules;
  };
  mkReceiverLib = import ./mk-receiver-lib.nix { inherit lib; };
  flakeConsumer = import ./flake-consumer.nix {
    inherit
      crossConfig
      flakeParts
      mkReceiverLib
      nixpkgs
      system
      ;
  };
  allAssertionsPass =
    nodes:
    lib.pipe nodes [
      builtins.attrValues
      (builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions))
    ];
  # Fail as NixOS `toplevel` does, so assertion messages match on both
  # evaluators.
  checkAssertions = node: lib.asserts.checkAssertWarn node.config.assertions [ ] node;
in
{
  inherit (evaluation) evaluateModule;
  inherit
    allAssertionsPass
    checkAssertions
    crossConfig
    flakeConsumer
    lib
    mkNodeCollection
    mkReceiverLib
    ;
  messagePattern = import ./message-pattern.nix { inherit lib; };
  contributionRejections = import ../fixtures/contributions.nix {
    inherit checkAssertions mkNodeCollection;
  };
  destinationRejections = import ../fixtures/destinations.nix {
    inherit checkAssertions mkNodeCollection;
  };
  moduleRejections = import ../fixtures/module-settings.nix {
    inherit (evaluation) evaluateConstructor evaluateModule;
  };
  flakeRejections = import ../fixtures/flake-module-settings.nix {
    inherit (flakeConsumer) evaluateConsumer;
  };
  taggedNixos = import ../fixtures/tagged-nixos.nix { inherit mkNodeCollection; };
  taggedPermissionsOption = import ../fixtures/tagged-permissions.nix { inherit lib; };
  taggedRejections = import ../fixtures/tagged-destinations.nix {
    inherit checkAssertions mkNodeCollection;
  };
  taggedValueCycle = import ../fixtures/tagged-value-cycle.nix { inherit mkNodeCollection; };
  valueCycle = import ../fixtures/value-cycle.nix { inherit mkNodeCollection; };
  minimalExample = import ../../examples/minimal.nix { inherit crossConfig nixpkgs system; };
  flakeExample = import ../../examples/flake-parts.nix {
    inherit
      crossConfig
      flakeParts
      nixpkgs
      system
      ;
  };
}
