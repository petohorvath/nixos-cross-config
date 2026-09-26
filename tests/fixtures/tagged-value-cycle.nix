{ mkNodes }:
let
  inventoryModule = { lib, ... }: {
    options.inventory = lib.mkOption {
      type = lib.types.attrTag {
        payload = lib.mkOption {
          type = lib.types.submodule {
            options.value = lib.mkOption {
              type = lib.types.str;
              description = "A tagged value supplied only by the other node.";
            };
          };
          description = "A writable tag participating in a value cycle.";
        };
      };
      description = "Inventory containing the cyclic contribution.";
    };
  };
  nodes = mkNodes {
    optionPaths = [
      [
        "inventory"
        "payload"
        "value"
      ]
    ];
    modules = {
      alpha = { config, ... }: {
        imports = [ inventoryModule ];
        crossConfig.contributions.beta.inventory.payload.value = config.inventory.payload.value;
      };
      beta = { config, ... }: {
        imports = [ inventoryModule ];
        crossConfig.contributions.alpha.inventory.payload.value = config.inventory.payload.value;
      };
    };
  };
in
builtins.mapAttrs (_: node: node.config.inventory.payload.value) nodes
