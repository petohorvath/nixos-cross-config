{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  repo = "cross-config";
  # The files the suites read, so documentation edits do not rebuild them.
  srcDir = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../examples
      ../flake-module.nix
      ../flake.nix
      ../lib
      ../nixos
      ./.
    ];
  };
  runNixUnit = import ./runners/nix-unit.nix {
    inherit
      inputs
      pkgs
      repo
      srcDir
      ;
  };
in
lib.foldl' lib.attrsets.unionOfDisjoint { } [
  {
    unit = runNixUnit { kind = "unit"; };
    # A group of NixOS evaluations can peak above 3 GiB, so run one at a time.
    integration = runNixUnit {
      kind = "integration";
      jobs = 1;
    };
  }
]
