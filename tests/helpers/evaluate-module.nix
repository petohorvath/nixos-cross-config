{ crossConfig, lib }:
let
  # Evaluate receiver modules without NixOS, declaring the assertions option
  # that participating modules define.
  evaluateModules =
    {
      modules,
      specialArgs ? { },
    }:
    lib.evalModules {
      inherit specialArgs;
      modules = [
        {
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
            description = "Assertions emitted by participating modules.";
          };
        }
      ]
      ++ modules;
    };
  evaluate =
    module: arguments: evaluateModules (arguments // { modules = [ module ] ++ arguments.modules; });
in
{
  inherit evaluateModules;
  evaluateModule = evaluate crossConfig.nixosModules.default;
  # Add the NixOS module to a configuration that another evaluation builds,
  # such as a NixOS container's.
  withNixosModule = module: {
    imports = [
      crossConfig.nixosModules.default
      module
    ];
  };
  evaluateConstructor = settings: evaluate (crossConfig.lib.mkModule settings);
}
