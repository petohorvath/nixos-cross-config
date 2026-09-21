{
  fixtureName,
  flakeParts,
  nixpkgs,
  system,
}:
builtins.toFile "cross-config-${fixtureName}" ''
  let
    crossConfig = (import ${../.}/flake.nix).outputs { };
    inherit (import ${./evaluation-inputs.nix} {
      flakePartsDir = "${flakeParts}";
      nixpkgsDir = "${nixpkgs}";
    }) flakeParts nixpkgs;
    mkNodes = import ${./.}/mk-nodes.nix {
      inherit crossConfig nixpkgs;
      system = "${system}";
    };
  in
  import ${./.}/${fixtureName} { inherit crossConfig flakeParts mkNodes nixpkgs; }
''
