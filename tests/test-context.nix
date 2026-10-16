# Builds testContext, the argument of every nix-unit suite. The unit entry
# point passes no flake-parts, so only the helpers and fixtures of the
# integration suites read it.
{
  flake-parts ? null,
  nixpkgs,
  system,
}:
let
  inherit (nixpkgs) lib;

  # The exports that flake.nix assembles, imported from source so that the
  # unit suites evaluate no flake.
  crossConfig = {
    lib = import ../lib;
    nixosModules.default = ../nixos/module.nix;
    flakeModules.default = ../flake-module.nix;
  };

  evaluation = import ./helpers/evaluate-module.nix { inherit crossConfig lib; };
  mkNodeCollection = import ./helpers/mk-node-collection.nix {
    inherit crossConfig lib system;
    inherit (evaluation) evaluateModules;
  };
  mkReceiverLib = import ./helpers/mk-receiver-lib.nix { inherit lib; };
  flakeConsumer = import ./helpers/flake-consumer.nix {
    inherit
      crossConfig
      flake-parts
      mkReceiverLib
      nixpkgs
      system
      ;
  };
  # Fail as NixOS `toplevel` does, so assertion messages match on both
  # evaluators.
  checkAssertions = node: lib.asserts.checkAssertWarn node.config.assertions [ ] node;
in
{
  inherit crossConfig lib;

  helpers = {
    inherit (evaluation) evaluateModule;
    inherit
      checkAssertions
      flakeConsumer
      mkNodeCollection
      mkReceiverLib
      ;
    flakeOutputs = import ./helpers/flake-outputs.nix { inherit flake-parts nixpkgs; };
    messagePattern = import ./helpers/message-pattern.nix { inherit lib; };
    allAssertionsPass =
      nodes:
      lib.pipe nodes [
        builtins.attrValues
        (builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions))
      ];
  };

  fixtures = {
    contributionRejections = import ./fixtures/contributions.nix {
      inherit checkAssertions mkNodeCollection;
    };
    destinationRejections = import ./fixtures/destinations.nix {
      inherit checkAssertions mkNodeCollection;
    };
    moduleRejections = import ./fixtures/module-settings.nix {
      inherit (evaluation) evaluateConstructor evaluateModule;
    };
    flakeRejections = import ./fixtures/flake-module-settings.nix {
      inherit (flakeConsumer) evaluateConsumer;
    };
    taggedNixos = import ./fixtures/tagged-nixos.nix { inherit mkNodeCollection; };
    taggedPermissionsOption = import ./fixtures/tagged-permissions.nix { inherit lib; };
    taggedRejections = import ./fixtures/tagged-destinations.nix {
      inherit checkAssertions mkNodeCollection;
    };
    taggedValueCycle = import ./fixtures/tagged-value-cycle.nix { inherit mkNodeCollection; };
    valueCycle = import ./fixtures/value-cycle.nix { inherit mkNodeCollection; };
    minimalExample = import ../examples/minimal.nix { inherit crossConfig nixpkgs system; };
    flakeExample = import ../examples/flake-parts.nix {
      inherit
        crossConfig
        flake-parts
        nixpkgs
        system
        ;
    };
  };
}
