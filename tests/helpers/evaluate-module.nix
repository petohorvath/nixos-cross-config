{ crossConfig, lib }:
let
  evaluate =
    module:
    {
      modules,
      specialArgs ? { },
    }:
    lib.evalModules {
      inherit specialArgs;
      modules = [
        module
        {
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
            description = ''
              Assertions emitted by participating modules.
            '';
          };
        }
      ]
      ++ modules;
    };
in
{
  evaluateModule = evaluate crossConfig.nixosModules.default;
  evaluateConstructor = args: evaluate (crossConfig.lib.mkModule args);
  constructorArguments = builtins.functionArgs crossConfig.lib.mkModule;
  withModule = module: {
    imports = [
      crossConfig.nixosModules.default
      module
    ];
  };
}
