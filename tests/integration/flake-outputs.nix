# The flake, self, exposes the same code that testContext imports from source.
{
  crossConfig,
  lib,
  self,
  ...
}:
let
  definitionPositions = attrs: lib.mapAttrs (name: _: builtins.unsafeGetAttrPos name attrs) attrs;
  # flake-parts wraps each exported NixOS module in layers of imports.
  importedPaths =
    module:
    if builtins.isPath module then
      [ module ]
    else
      builtins.concatMap importedPaths (module.imports or [ ]);
in
{
  testLib = {
    expr = definitionPositions self.lib;
    expected = definitionPositions crossConfig.lib;
  };
  testNixosModule = {
    expr = importedPaths self.nixosModules.default;
    expected = [ crossConfig.nixosModules.default ];
  };
  testFlakeModule = {
    expr = self.flakeModules.default;
    expected = crossConfig.flakeModules.default;
  };
}
