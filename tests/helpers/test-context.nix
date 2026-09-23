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
    ;
  messagePattern = import ./message-pattern.nix { inherit lib; };
  checkAssertions =
    nodes:
    lib.pipe nodes [
      builtins.attrValues
      (builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions))
    ];
  moduleRejections = import ../fixtures/module-settings.nix {
    inherit (evaluation) evaluateConstructor evaluateModule;
  };
  flakeRejections = import ../fixtures/flake-module-settings.nix {
    inherit (flakeConsumer) evaluateConsumer;
  };
  taggedNixos = import ../fixtures/tagged-nixos.nix { inherit mkNodes; };
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
