# The flake exposes the same code that testContext imports from source.
{
  crossConfig,
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) flakeOutputs;
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
    expr = definitionPositions flakeOutputs.lib;
    expected = definitionPositions crossConfig.lib;
  };
  testNixosModule = {
    expr = importedPaths flakeOutputs.nixosModules.default;
    expected = [ crossConfig.nixosModules.default ];
  };
  testFlakeModule = {
    expr = flakeOutputs.flakeModules.default;
    expected = crossConfig.flakeModules.default;
  };
}
