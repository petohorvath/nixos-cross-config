{ mkNodes }:
let
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

  mkReadOnlyWrapper =
    wrapper:
    mkReceiver (
      { lib, ... }:
      let
        value = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = ''
            Read-only destination inside a native option-type wrapper.
          '';
        };
        submodule = lib.types.submodule { options = { inherit value; }; };
        wrapperTypes = {
          coerced = lib.types.coercedTo lib.types.str (value: { inherit value; }) submodule;
          either = lib.types.either lib.types.str submodule;
          nullable = lib.types.nullOr submodule;
          unique = lib.types.uniq submodule;
          tagged = lib.types.attrTag { inherit value; };
        };
      in
      {
        options.inventory = lib.mkOption {
          type = wrapperTypes.${wrapper};
          default = if wrapper == "tagged" then { value = "local"; } else { };
          description = "Inventory using a native option-type wrapper.";
        };
      }
    );

  mkUnknownReceiver =
    sender:
    mkNodes {
      optionPaths = [
        [
          "inventory"
          "value"
        ]
      ];
      modules = { inherit sender; };
    };
in
{
  incompatibleDestination =
    (mkReceiver (
      { lib, ... }:
      {
        options.inventory.value = lib.mkOption {
          type = lib.types.int;
          description = "Destination requiring an integer.";
        };
      }
    )).config.inventory.value;
  conflictingDestination =
    (mkReceiver (
      { lib, ... }:
      {
        options.inventory.value = lib.mkOption {
          type = lib.types.str;
          description = "Destination with a conflicting local definition.";
        };
        config.inventory.value = "local";
      }
    )).config.inventory.value;
}
// builtins.mapAttrs (_: node: node.config.system.build.toplevel.drvPath) {
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
              description = ''
                A read-only option selected by receiving submodule name.
              '';
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
                description = ''
                  A value protected by receiver-local configuration.
                '';
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
        description = ''
          Read-only destination without a default or local definition.
        '';
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
  readOnlyCoercedDestination = mkReadOnlyWrapper "coerced";
  readOnlyEitherDestination = mkReadOnlyWrapper "either";
  readOnlyNullableDestination = mkReadOnlyWrapper "nullable";
  readOnlyUniqueDestination = mkReadOnlyWrapper "unique";
  readOnlyTaggedDestination = mkReadOnlyWrapper "tagged";
  unknownReceiver = (mkUnknownReceiver ./destination-sender.nix).sender;
  unknownReceiverWithDisabledContribution =
    (mkUnknownReceiver (
      { lib, ... }: {
        crossConfig.nodes.receiver.inventory.value = lib.mkIf false (
          throw "Disabled contribution was evaluated."
        );
      }
    )).sender;
  unregisteredDestination =
    (mkNodes {
      optionPaths = [ ];
      modules = {
        sender = ./destination-sender.nix;
        receiver = { };
      };
    }).sender;
}
