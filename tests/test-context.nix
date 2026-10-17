# Builds testContext, the argument of every nix-unit suite. The unit entry
# point passes only nixpkgs, so only the helpers, fixtures, and suites of the
# integration entry point read flake-parts, self, and system.
{
  flake-parts ? null,
  nixpkgs,
  self ? null,
  system ? null,
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

  # Every NixOS node that the helpers build reads this one package set;
  # instantiating nixpkgs per node costs memory that nix-unit never frees.
  sharedPkgsModule = {
    imports = [ nixpkgs.nixosModules.readOnlyPkgs ];
    nixpkgs.pkgs = nixpkgs.legacyPackages.${system};
  };

  evaluation = import ./helpers/evaluate-module.nix { inherit crossConfig lib; };
  mkNodeCollection = import ./helpers/mk-node-collection.nix {
    inherit crossConfig lib sharedPkgsModule;
    inherit (evaluation) evaluateModules;
  };
  mkReceiverLib = import ./helpers/mk-receiver-lib.nix { inherit lib; };
  flakeConsumer = import ./helpers/flake-consumer.nix {
    inherit
      crossConfig
      flake-parts
      mkReceiverLib
      nixpkgs
      sharedPkgsModule
      ;
  };
  # Fail as NixOS `toplevel` does, so assertion messages match on both
  # evaluators.
  checkAssertions = node: lib.asserts.checkAssertWarn node.config.assertions [ ] node;
in
{
  inherit lib self;
  # Suites reach the modules through the helpers.
  crossConfig = { inherit (crossConfig) lib; };

  helpers = {
    inherit (evaluation) evaluateModule evaluateModules withNixosModule;
    inherit
      checkAssertions
      flakeConsumer
      mkNodeCollection
      mkReceiverLib
      ;
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
    examples = {
      minimal = import ../examples/minimal.nix { inherit crossConfig nixpkgs system; };
      flake-parts = import ../examples/flake-parts.nix {
        inherit
          crossConfig
          flake-parts
          nixpkgs
          system
          ;
      };
    };
  };
}
