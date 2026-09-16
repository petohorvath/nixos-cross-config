{
  fixtureName,
  nixpkgs,
  system,
}:
builtins.toFile "cross-config-${fixtureName}" ''
  let
    crossConfig = (import ${../.}/flake.nix).outputs { };
    nixpkgs = (import ${nixpkgs}/flake.nix).outputs {
      self.outPath = "${nixpkgs}";
    };
    mkNodes = import ${./.}/mk-nodes.nix {
      inherit crossConfig nixpkgs;
      system = "${system}";
    };
  in
  import ${./.}/${fixtureName} { inherit mkNodes; }
''
