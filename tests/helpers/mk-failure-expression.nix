{
  fixtureName,
  flakeParts,
  nixpkgs,
  system,
}:
builtins.toFile "cross-config-${fixtureName}" ''
  let
    inherit (import ${./evaluation-inputs.nix} {
      flakePartsDir = "${flakeParts}";
      nixpkgsDir = "${nixpkgs}";
    }) flakeParts nixpkgs;
    crossConfig = import ${../..}/tests/helpers/flake-outputs.nix { inherit flakeParts nixpkgs; };
    mkNodes = import ${./.}/mk-nodes.nix {
      inherit crossConfig nixpkgs;
      system = "${system}";
    };
  in
  import ${../.}/${fixtureName} { inherit crossConfig flakeParts mkNodes nixpkgs; }
''
