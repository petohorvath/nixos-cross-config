{
  crossConfig,
  flake-parts,
  mkReceiverLib,
  nixpkgs,
  sharedPkgsModule,
}:
let
  inherit (nixpkgs) lib;
  consumerModule = flakeModule: module: {
    imports = [
      flakeModule
      module
    ];
    systems = [ ];
  };
  # Evaluate a consumer of any flake module, such as the flake's own export.
  evaluateFlakeModule =
    flakeModule: module:
    flake-parts.lib.evalFlakeModule { inputs.self.outPath = ../..; } (
      consumerModule flakeModule module
    );
  evaluateConsumer = evaluateFlakeModule crossConfig.flakeModules.default;
  mkConsumer =
    module:
    flake-parts.lib.mkFlake { inputs.self.outPath = ../..; } (
      consumerModule crossConfig.flakeModules.default module
    );
  mkUnconfiguredNode =
    modules:
    lib.nixosSystem {
      modules = [ sharedPkgsModule ] ++ modules;
    };
  mkNode =
    {
      configuredModule,
      name,
      nodeModule,
    }:
    lib.nixosSystem {
      specialArgs.lib = mkReceiverLib name;
      modules = [
        sharedPkgsModule
        configuredModule
        {
          options.inventory = lib.genAttrs [ "values" "literal.values" ] (
            _:
            lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Received and local inventory values.";
            }
          );
          config = {
            boot.isContainer = true;
            system.stateVersion = "26.05";
            networking.hostName = "${name}-container";
            crossConfig.name = name;
            inventory.values = [ "local-${name}" ];
          };
        }
        nodeModule
      ];
    };
  mkPairConsumer =
    sharedModules: nodeModule:
    mkConsumer (
      { config, ... }:
      {
        imports = sharedModules;
        flake.nixosConfigurations = lib.genAttrs [ "alpha" "beta" ] (
          name:
          mkNode {
            configuredModule = config.flake.nixosModules.crossConfig;
            inherit name nodeModule;
          }
        );
      }
    );
in
{
  inherit
    evaluateConsumer
    evaluateFlakeModule
    mkConsumer
    mkNode
    mkPairConsumer
    mkUnconfiguredNode
    ;
}
