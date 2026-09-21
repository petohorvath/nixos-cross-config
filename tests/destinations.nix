{ checkAssertions, mkNodes }:
let
  inventoryModule =
    { lib, ... }:
    {
      options.inventory = {
        serial = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "default-serial";
          description = "Serial supplied by the option declaration.";
        };
        model = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Model supplied by the receiver.";
        };
        unassigned = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Read-only option without a definition.";
        };
      };
      config.inventory.model = "local-model";
    };
in
{
  ordinaryReadOnlyOption =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "services"
            "neo4j"
            "unavailable"
          ]
        ];
        modules.idle = { };
      };
    in
    {
      testMissingOption = {
        expr = nodes.idle.config.services.neo4j ? unavailable;
        expected = false;
      };
      testReadOnly = {
        expr = nodes.idle.config.services.neo4j.readOnly;
        expected = false;
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  selfConditionalSubmodule =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "inventory"
            "value"
          ]
        ];
        modules.application = { config, lib, ... }: {
          options.inventory = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "the conditional self contribution" // {
                  default = true;
                };
                value = lib.mkOption {
                  type = lib.types.str;
                  default = "local";
                  description = "Value receiving a conditional self contribution.";
                };
              };
            };
            default = { };
            description = "Inventory with a conditional self contribution.";
          };
          config.crossConfig.nodes.application.inventory.value =
            lib.mkIf config.inventory.enable "contributed";
        };
      };
    in
    {
      testValue = {
        expr = nodes.application.config.inventory.value;
        expected = "contributed";
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  unusedMissingWithReceivedCondition =
    let
      nodes = mkNodes {
        optionPaths = [
          [ "gate" ]
          [
            "inventory"
            "entries"
            "example"
            "missing"
          ]
        ];
        modules = {
          sender.crossConfig.nodes.receiver.gate = true;
          receiver =
            { config, lib, ... }:
            {
              options = {
                gate = lib.mkOption {
                  type = lib.types.bool;
                  description = "A contributed condition for receiver-local values.";
                };
                inventory.entries = lib.mkOption {
                  type = lib.types.attrsOf (
                    lib.types.submodule {
                      options.value = lib.mkOption {
                        type = lib.types.str;
                        default = "default";
                        description = "Value declared independently of the condition.";
                      };
                    }
                  );
                  default = { };
                  description = "Receiver-local entries controlled by a received value.";
                };
              };
              config.inventory.entries = lib.mkIf config.gate {
                example.value = "local";
              };
            };
        };
      };
    in
    {
      testReceivedCondition = {
        expr = nodes.receiver.config.gate;
        expected = true;
      };
      testLocalValue = {
        expr = nodes.receiver.config.inventory.entries.example.value;
        expected = "local";
      };
      testMissingChild = {
        expr = nodes.receiver.config.inventory.entries.example ? missing;
        expected = false;
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  namedSubmoduleOption =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "inventory"
            "entries"
            "writable"
            "value"
          ]
        ];
        modules = {
          sender.crossConfig.nodes.receiver.inventory.entries.writable.value = "contributed";
          receiver =
            { lib, ... }:
            {
              options.inventory.entries = lib.mkOption {
                type = lib.types.attrsOf (
                  lib.types.submodule (
                    { name, ... }:
                    {
                      options.value = lib.mkOption {
                        type = lib.types.str;
                        readOnly = name != "writable";
                        default = "local";
                        description = "Only the named writable entry accepts contributions.";
                      };
                    }
                  )
                );
                default = { };
                description = "Inventory entries with per-name write permissions.";
              };
            };
        };
      };
    in
    {
      testValue = {
        expr = nodes.receiver.config.inventory.entries.writable.value;
        expected = "contributed";
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  receiverLocalSubmoduleDeclaration =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "inventory"
            "entries"
            "example"
            "value"
          ]
        ];
        modules = {
          sender.crossConfig.nodes.receiver.inventory.entries.example.value = "contributed";
          receiver =
            { lib, ... }:
            {
              options.inventory.entries = lib.mkOption {
                type = lib.types.attrsOf (lib.types.submodule { });
                default = { };
                description = "Inventory entries with receiver-owned declarations.";
              };
              config.inventory.entries.example = { lib, ... }: {
                options.value = lib.mkOption {
                  type = lib.types.str;
                  description = "Option declared in one receiver instance.";
                };
                config.value = lib.mkDefault "local";
              };
            };
        };
      };
    in
    {
      testValue = {
        expr = nodes.receiver.config.inventory.entries.example.value;
        expected = "contributed";
      };
      testDeclaredOptions = {
        expr = builtins.attrNames nodes.receiver.config.inventory.entries.example;
        expected = [ "value" ];
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  receiverLocalFreeformType =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "inventory"
            "extra"
          ]
        ];
        modules = {
          sender.crossConfig.nodes.receiver.inventory.extra = "contributed";
          receiver =
            { lib, ... }:
            {
              options.inventory = lib.mkOption {
                type = lib.types.submodule { };
                default = { };
                description = "Inventory with receiver-local freeform fields.";
              };
              config.inventory = { lib, ... }: {
                _module.freeformType = lib.types.attrsOf lib.types.str;
                value = "local";
              };
            };
        };
      };
    in
    {
      testInventory = {
        expr = nodes.receiver.config.inventory;
        expected = {
          value = "local";
          extra = "contributed";
        };
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  unusedWrappedSubmoduleOption =
    let
      mkCase =
        wrapper:
        let
          nodes = mkNodes {
            optionPaths = [
              [
                "inventory"
                "missing"
              ]
            ];
            modules.idle =
              { lib, ... }:
              let
                submodule = lib.types.submodule {
                  options.value = lib.mkOption {
                    type = lib.types.str;
                    default = "local";
                    description = "The wrapped submodule's local value.";
                  };
                };
                types = {
                  coerced = lib.types.coercedTo lib.types.str (value: { inherit value; }) submodule;
                  either = lib.types.either lib.types.str submodule;
                  nullable = lib.types.nullOr submodule;
                  unique = lib.types.uniq submodule;
                  tagged = lib.types.attrTag {
                    value = lib.mkOption {
                      type = lib.types.str;
                      description = "The only permitted tag.";
                    };
                  };
                };
              in
              {
                options.inventory = lib.mkOption {
                  type = types.${wrapper};
                  default = {
                    value = "local";
                  };
                  description = "Inventory using a native option-type wrapper.";
                };
              };
          };
        in
        {
          testLocalValue = {
            expr = nodes.idle.config.inventory.value;
            expected = "local";
          };
          testMissingChild = {
            expr = nodes.idle.config.inventory ? missing;
            expected = false;
          };
          testAssertions = {
            expr = checkAssertions nodes;
            expected = true;
          };
        };
    in
    builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = mkCase name;
        })
        [
          "coerced"
          "either"
          "nullable"
          "unique"
          "tagged"
        ]
    );

  unusedMissing =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "unavailable"
            "value"
          ]
          [
            "networking"
            "unavailable"
          ]
          [
            "networking"
            "firewall"
            "allowedTCPPorts"
          ]
        ];
        modules = {
          idle = { };
          sender.crossConfig.nodes.receiver.networking.firewall.allowedTCPPorts = [ 8080 ];
          receiver = { };
        };
      };
    in
    {
      testIdleMissing = {
        expr = nodes.idle.config ? unavailable;
        expected = false;
      };
      testSenderMissing = {
        expr = nodes.sender.config ? unavailable;
        expected = false;
      };
      testReceiverMissing = {
        expr = nodes.receiver.config ? unavailable;
        expected = false;
      };
      testNestedMissing = {
        expr = nodes.receiver.config.networking ? unavailable;
        expected = false;
      };
      testPorts = {
        expr = nodes.receiver.config.networking.firewall.allowedTCPPorts;
        expected = [ 8080 ];
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  unusedReadOnly =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "inventory"
            "serial"
          ]
          [
            "inventory"
            "model"
          ]
          [
            "inventory"
            "unassigned"
          ]
          [
            "networking"
            "firewall"
            "allowedTCPPorts"
          ]
        ];
        modules = {
          idle = inventoryModule;
          sender.crossConfig.nodes.receiver.networking.firewall.allowedTCPPorts = [ 8080 ];
          receiver = inventoryModule;
        };
      };
    in
    {
      testLocalReadOnlyValues = {
        expr =
          builtins.all
            (
              node:
              node.config.inventory.serial == "default-serial"
              && node.config.inventory.model == "local-model"
              && !node.options.inventory.unassigned.isDefined
            )
            [
              nodes.idle
              nodes.receiver
            ];
        expected = true;
      };
      testPorts = {
        expr = nodes.receiver.config.networking.firewall.allowedTCPPorts;
        expected = [ 8080 ];
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  unusedMissingSubmoduleOption =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "environment"
            "etc"
            "application.conf"
            "unavailable"
          ]
          [
            "networking"
            "firewall"
            "allowedTCPPorts"
          ]
        ];
        modules = {
          idle = { };
          sender.crossConfig.nodes.receiver.networking.firewall.allowedTCPPorts = [ 8080 ];
          receiver = { };
        };
      };
    in
    {
      testIdleEntry = {
        expr = nodes.idle.config.environment.etc ? "application.conf";
        expected = false;
      };
      testReceiverEntry = {
        expr = nodes.receiver.config.environment.etc ? "application.conf";
        expected = false;
      };
      testPorts = {
        expr = nodes.receiver.config.networking.firewall.allowedTCPPorts;
        expected = [ 8080 ];
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  disabledInvalidDestinations =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "unavailable"
            "value"
          ]
          [
            "inventory"
            "serial"
          ]
        ];
        modules = {
          sender =
            { lib, ... }:
            {
              crossConfig.nodes = {
                receiver = {
                  unavailable.value = lib.mkIf false (throw "Disabled missing destination was evaluated.");
                  inventory.serial = lib.mkIf false (throw "Disabled read-only destination was evaluated.");
                };
                unknown = lib.mkIf false (throw "Disabled receiver was evaluated.");
              };
            };
          receiver = inventoryModule;
        };
      };
    in
    {
      testMissingDestination = {
        expr = nodes.receiver.config ? unavailable;
        expected = false;
      };
      testLocalSerial = {
        expr = nodes.receiver.config.inventory.serial;
        expected = "default-serial";
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };

  unusedReadOnlySubmoduleOption =
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "inventory"
            "entry"
            "serial"
          ]
        ];
        modules = {
          idle = { };
          receiver =
            { lib, ... }:
            {
              options.inventory.entry = lib.mkOption {
                type = lib.types.submodule {
                  options.serial = lib.mkOption {
                    type = lib.types.str;
                    readOnly = true;
                    default = "local-serial";
                    description = "Serial within a receiving submodule.";
                  };
                };
                default = { };
                description = "Receiver-owned inventory entry.";
              };
            };
        };
      };
    in
    {
      testLocalSerial = {
        expr = nodes.receiver.config.inventory.entry.serial;
        expected = "local-serial";
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };
}
