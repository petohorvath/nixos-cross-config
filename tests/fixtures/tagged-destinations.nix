{ mkNodes }:
let
  submoduleOption =
    lib:
    lib.mkOption {
      type = lib.types.submodule {
        options.value = lib.mkOption {
          type = lib.types.str;
          default = "local";
          description = "A writable tagged field.";
        };
      };
      description = "A writable tag.";
    };
  readOnlySubmodule =
    lib:
    lib.types.submodule {
      options.value = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "local";
        description = "A read-only child below a writable tag.";
      };
    };
  mkReceiver =
    {
      tagOption,
      receiverDefinitions ? _: [ ],
      senderDefinitions ? _: [ "contributed" ],
      tagName ? "payload",
      leafPath ? [ "value" ],
      receiverModules ? [ ],
    }:
    (mkNodes {
      optionPaths = [
        (
          [
            "inventory"
            "payload"
          ]
          ++ leafPath
        )
      ];
      modules = {
        sender = { lib, ... }: {
          _file = toString ./tagged-destinations.nix;
          crossConfig.nodes.receiver = lib.setAttrByPath (
            [
              "inventory"
              "payload"
            ]
            ++ leafPath
          ) (lib.mkMerge (senderDefinitions lib));
        };
        receiver = { lib, ... }: {
          _file = toString ./tagged-destinations.nix;
          imports = receiverModules;
          options.inventory = lib.mkOption {
            type = lib.types.attrTag { ${tagName} = tagOption lib; };
            description = ''
              Tagged destinations used to verify failure diagnostics.
            '';
          };
          config.inventory = lib.mkMerge (receiverDefinitions lib);
        };
      };
    }).receiver;

  assertionFailures = {
    taggedMissingTag = mkReceiver {
      tagOption = submoduleOption;
      tagName = "other";
    };
    taggedReadOnlyTag = mkReceiver {
      tagOption = lib: submoduleOption lib // { readOnly = true; };
    };
    taggedMissingChild = mkReceiver {
      tagOption =
        lib:
        lib.mkOption {
          type = lib.types.submodule { };
          description = "A writable tag without the contributed child.";
        };
    };
    taggedReadOnlyChild = mkReceiver {
      tagOption =
        lib:
        lib.mkOption {
          type = readOnlySubmodule lib;
          description = "A writable tag containing a read-only child.";
        };
    };
    taggedReadOnlyName = mkReceiver {
      tagOption =
        lib:
        lib.mkOption {
          type = lib.types.submodule (
            { name, ... }: {
              options.value = lib.mkOption {
                type = lib.types.str;
                default = "local";
                readOnly = name == "payload";
                description = "A child locked by its original tag name.";
              };
            }
          );
          description = "A tag with name-dependent child permissions.";
        };
    };
    taggedReadOnlyLocal = mkReceiver {
      tagOption = lib: import ./tagged-permissions.nix { inherit lib; };
      receiverDefinitions = _: [ { payload.locked = true; } ];
    };
    taggedInspectionDefinitionSource = mkReceiver {
      tagOption = lib: import ./tagged-permissions.nix { inherit lib; };
      receiverModules = [ ./tagged-invalid-local.nix ];
    };
  }
  //
    builtins.mapAttrs
      (
        _: wrap:
        mkReceiver {
          tagOption =
            lib:
            lib.mkOption {
              type = wrap lib (readOnlySubmodule lib);
              description = "A writable tag wrapping a read-only child.";
            };
        }
      )
      {
        taggedReadOnlyCoerced =
          lib:
          lib.types.coercedTo lib.types.str (value: {
            inherit value;
          });
        taggedReadOnlyEither = lib: lib.types.either lib.types.str;
        taggedReadOnlyNullable = lib: lib.types.nullOr;
        taggedReadOnlyUnique = lib: lib.types.uniq;
      };
in
builtins.mapAttrs (_: receiver: receiver.config.system.build.toplevel.drvPath) assertionFailures
// {
  taggedIncompatible =
    (mkReceiver {
      tagOption =
        lib:
        lib.mkOption {
          type = lib.types.submodule {
            options.value = lib.mkOption {
              type = lib.types.int;
              description = "A child requiring an integer.";
            };
          };
          description = "A tag receiving an invalid child value.";
        };
    }).config.inventory.payload.value;
  taggedConflict =
    (mkReceiver {
      tagOption = submoduleOption;
      receiverDefinitions = _: [ { payload.value = "receiver"; } ];
    }).config.inventory.payload.value;
  taggedDefaultSource =
    (mkReceiver {
      leafPath = [ ];
      tagOption = lib: import ./tagged-default.nix { inherit lib; };
      senderDefinitions = lib: [ (lib.mkIf false (throw "Disabled contribution was forced.")) ];
      receiverDefinitions = lib: [ { payload = lib.mkIf false "unused"; } ];
    }).config.inventory.payload;
}
