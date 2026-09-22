{ mkNodes }:
let
  mkReadOnlyWrapper =
    wrapper:
    mkReceiver (
      { lib, ... }:
      let
        value = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Read-only destination inside a native option-type wrapper.";
        };
        submodule = lib.types.submodule { options = { inherit value; }; };
        types = {
          coerced = lib.types.coercedTo lib.types.str (value: { inherit value; }) submodule;
          either = lib.types.either lib.types.str submodule;
          nullable = lib.types.nullOr submodule;
          unique = lib.types.uniq submodule;
          tagged = lib.types.attrTag { inherit value; };
        };
      in
      {
        options.inventory = lib.mkOption {
          type = types.${wrapper};
          default = if wrapper == "tagged" then { value = "local"; } else { };
          description = "Inventory using a native option-type wrapper.";
        };
      }
    );

  mkReceiver =
    receiver:
    (mkNodes {
      optionPaths = [
        [
          "inventory"
          "value"
        ]
      ];
      modules = {
        sender = ./destination-sender.nix;
        inherit receiver;
      };
    }).receiver;

  missingDestination = mkReceiver { };
  readOnlyNamedDestination = mkReceiver (
    { lib, ... }:
    {
      options.inventory = lib.mkOption {
        type = lib.types.submodule (
          { name, ... }:
          {
            options.value = lib.mkOption {
              type = lib.types.str;
              readOnly = name == "inventory";
              description = "A read-only option selected by receiving submodule name.";
            };
          }
        );
        default = { };
        description = "Inventory with name-dependent write permissions.";
      };
    }
  );
  readOnlyLocalSubmoduleConfig = mkReceiver (
    { lib, ... }:
    {
      options.inventory = lib.mkOption {
        type = lib.types.submodule (
          { config, ... }:
          {
            options = {
              locked = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the receiver locks its inventory.";
              };
              value = lib.mkOption {
                type = lib.types.str;
                readOnly = config.locked;
                description = "A value protected by receiver-local configuration.";
              };
            };
          }
        );
        default = { };
        description = "Inventory with local write permissions.";
      };
      config.inventory.locked = true;
    }
  );
  missingSubmoduleDestination = mkReceiver (
    { lib, ... }:
    {
      options.inventory = lib.mkOption {
        type = lib.types.submodule { };
        default = { };
        description = "Submodule without the registered destination.";
      };
    }
  );
  readOnlySubmoduleDestination = mkReceiver (
    { lib, ... }:
    {
      options.inventory = lib.mkOption {
        type = lib.types.submodule {
          options.value = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            description = "Read-only receiving submodule option.";
          };
        };
        default = { };
        description = "Submodule with a read-only destination.";
      };
    }
  );
  readOnlyDestination = mkReceiver (
    { lib, ... }:
    {
      options.inventory.value = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Read-only destination without a default or local definition.";
      };
    }
  );
  readOnlyDefault = mkReceiver (
    { lib, ... }:
    {
      options.inventory.value = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "local";
        description = "Read-only destination with a default.";
      };
    }
  );
  readOnlyLocal = mkReceiver (
    { lib, ... }:
    {
      options.inventory.value = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Read-only destination with a local definition.";
      };
      config.inventory.value = "local";
    }
  );
  incompatibleDestination = mkReceiver (
    { lib, ... }:
    {
      options.inventory.value = lib.mkOption {
        type = lib.types.int;
        description = "Destination requiring an integer.";
      };
    }
  );
  conflictingDestination = mkReceiver (
    { lib, ... }:
    {
      options.inventory.value = lib.mkOption {
        type = lib.types.str;
        description = "Destination with a conflicting local definition.";
      };
      config.inventory.value = "local";
    }
  );
  unknownReceiver = mkNodes {
    optionPaths = [
      [
        "inventory"
        "value"
      ]
    ];
    modules.sender = ./destination-sender.nix;
  };
  unregisteredDestination = mkNodes {
    optionPaths = [ ];
    modules = {
      sender = ./destination-sender.nix;
      receiver = { };
    };
  };
in
{
  missingDestination = missingDestination.config.system.build.toplevel.drvPath;
  readOnlyNamedDestination = readOnlyNamedDestination.config.system.build.toplevel.drvPath;
  readOnlyLocalSubmoduleConfig = readOnlyLocalSubmoduleConfig.config.system.build.toplevel.drvPath;
  missingSubmoduleDestination = missingSubmoduleDestination.config.system.build.toplevel.drvPath;
  readOnlySubmoduleDestination = readOnlySubmoduleDestination.config.system.build.toplevel.drvPath;
  readOnlyDestination = readOnlyDestination.config.system.build.toplevel.drvPath;
  readOnlyDefault = readOnlyDefault.config.system.build.toplevel.drvPath;
  readOnlyLocal = readOnlyLocal.config.system.build.toplevel.drvPath;
  incompatibleDestination = incompatibleDestination.config.inventory.value;
  conflictingDestination = conflictingDestination.config.inventory.value;
  unknownReceiver = unknownReceiver.sender.config.system.build.toplevel.drvPath;
  unregisteredDestination = unregisteredDestination.sender.config.system.build.toplevel.drvPath;
}
// builtins.mapAttrs (_: receiver: receiver.config.system.build.toplevel.drvPath) {
  readOnlyCoercedDestination = mkReadOnlyWrapper "coerced";
  readOnlyEitherDestination = mkReadOnlyWrapper "either";
  readOnlyNullableDestination = mkReadOnlyWrapper "nullable";
  readOnlyUniqueDestination = mkReadOnlyWrapper "unique";
  readOnlyTaggedDestination = mkReadOnlyWrapper "tagged";
}
