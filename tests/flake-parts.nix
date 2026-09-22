{ crossConfig }:
{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (inputs) nixpkgs;
  flakeParts = inputs.flake-parts;
  forSystems = lib.genAttrs config.systems;
in
{
  flake.lib = {
    tests = forSystems (
      system:
      import ./. {
        inherit
          crossConfig
          flakeParts
          nixpkgs
          system
          ;
      }
    );
    failures = forSystems (
      system:
      let
        mkNodes = import ./helpers/mk-nodes.nix {
          inherit crossConfig nixpkgs system;
        };
      in
      import ./failures.nix {
        inherit
          crossConfig
          flakeParts
          mkNodes
          nixpkgs
          ;
      }
      // {
        valueCycle = import ./value-cycle.nix { inherit mkNodes; };
        taggedValueCycle = import ./tagged-value-cycle.nix { inherit mkNodes; };
      }
    );
  };

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      checks = import ./checks.nix {
        inherit (config) formatter;
        inherit
          flakeParts
          nixpkgs
          pkgs
          system
          ;
      };
    };
}
