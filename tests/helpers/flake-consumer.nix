{
  crossConfig,
  flakeParts,
  mkReceiverLib,
  nixpkgs,
  system,
}:
let
  inherit (nixpkgs) lib;
  consumerModule = module: {
    imports = [
      crossConfig.flakeModules.default
      module
    ];
    systems = [ ];
  };
  evaluateConsumer =
    module: flakeParts.lib.evalFlakeModule { inputs.self.outPath = ../..; } (consumerModule module);
  mkConsumer =
    module: flakeParts.lib.mkFlake { inputs.self.outPath = ../..; } (consumerModule module);
  mkUnconfiguredNode =
    modules:
    lib.nixosSystem {
      inherit modules system;
    };
  mkNode =
    {
      configuredModule,
      name,
      nodeModule,
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs.lib = mkReceiverLib name;
      modules = [
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
    mkConsumer
    mkNode
    mkPairConsumer
    mkUnconfiguredNode
    ;
}
