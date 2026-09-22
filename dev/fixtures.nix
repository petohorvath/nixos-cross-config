# Focused evaluation uses the root selection unless nixpkgs is supplied explicitly.
{
  nixpkgs ? (builtins.getFlake (toString ../.)).inputs.nixpkgs,
  system ? builtins.currentSystem,
}:
let
  inherit
    (import ../tests/helpers/evaluation-inputs.nix {
      flakePartsDir = (builtins.getFlake (toString ../.)).inputs.flake-parts.outPath;
      nixpkgsDir = nixpkgs.outPath;
    })
    flakeParts
    ;
  crossConfig = import ../tests/helpers/flake-outputs.nix { inherit flakeParts nixpkgs; };
  mkNodes = import ../tests/helpers/mk-nodes.nix { inherit crossConfig nixpkgs system; };
in
{
  tests = import ../tests {
    inherit
      crossConfig
      flakeParts
      nixpkgs
      system
      ;
  };
  failures =
    import ../tests/failures.nix {
      inherit
        crossConfig
        flakeParts
        mkNodes
        nixpkgs
        ;
    }
    // {
      valueCycle = import ../tests/value-cycle.nix { inherit mkNodes; };
      taggedValueCycle = import ../tests/tagged-value-cycle.nix { inherit mkNodes; };
    };
}
