{
  crossConfig,
  flakeParts,
  nixpkgs,
  system,
}:
let
  inherit (nixpkgs) lib;
  evaluation = import ./evaluate-module.nix { inherit crossConfig lib; };
  mkNodes = import ./mk-nodes.nix { inherit crossConfig nixpkgs system; };
  mkModuleNodes = import ./mk-module-nodes.nix {
    inherit lib;
    inherit (evaluation) evaluateModule;
  };
  mkTaggedNodes = import ./mk-tagged-nodes.nix {
    inherit lib mkModuleNodes;
  };
  flakeConsumer = import ./flake-consumer.nix {
    inherit
      crossConfig
      flakeParts
      nixpkgs
      system
      ;
  };
in
evaluation
// {
  inherit
    flakeConsumer
    lib
    mkModuleNodes
    mkNodes
    mkTaggedNodes
    ;
  messagePattern = import ./message-pattern.nix { inherit lib; };
  allAssertionsPass =
    nodes:
    lib.pipe nodes [
      builtins.attrValues
      (builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions))
    ];
  contributionRejections = import ../fixtures/contributions.nix { inherit mkNodes; };
  destinationRejections = import ../fixtures/destinations.nix { inherit mkNodes; };
  moduleRejections = import ../fixtures/module-settings.nix {
    inherit (evaluation) evaluateConstructor evaluateModule;
  };
  flakeRejections = import ../fixtures/flake-module-settings.nix {
    inherit (flakeConsumer) evaluateConsumer;
  };
  taggedNixos = import ../fixtures/tagged-nixos.nix { inherit mkNodes; };
  taggedPermissionsOption = import ../fixtures/tagged-permissions.nix { inherit lib; };
  taggedRejections = import ../fixtures/tagged-destinations.nix { inherit mkNodes; };
  taggedValueCycle = import ../fixtures/tagged-value-cycle.nix { inherit mkNodes; };
  valueCycle = import ../fixtures/value-cycle.nix { inherit mkNodes; };
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
