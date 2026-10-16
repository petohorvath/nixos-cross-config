# The flake, self, exposes the same code that testContext imports from source.
{
  crossConfig,
  helpers,
  lib,
  self,
  ...
}:
let
  inherit (helpers) evaluateModule evaluateModules flakeConsumer;
  definitionPositions = attrs: lib.mapAttrs (name: _: builtins.unsafeGetAttrPos name attrs) attrs;
  # The files declaring each setting show which module an evaluation read.
  settingDeclarations =
    evaluation: lib.mapAttrs (_: option: option.declarations) evaluation.options.crossConfig;
in
{
  testLib = {
    expr = definitionPositions self.lib;
    expected = definitionPositions crossConfig.lib;
  };
  testNixosModule = {
    expr = settingDeclarations (evaluateModules {
      modules = [ self.nixosModules.default ];
    });
    expected = settingDeclarations (evaluateModule {
      modules = [ ];
    });
  };
  testFlakeModule = {
    expr = settingDeclarations (flakeConsumer.evaluateFlakeModule self.flakeModules.default { });
    expected = settingDeclarations (flakeConsumer.evaluateConsumer { });
  };
}
