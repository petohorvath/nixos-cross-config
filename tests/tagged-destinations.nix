{
  checkAssertions,
  crossConfig,
  nixpkgs,
  system,
}:
let
  rejections = import ./fixtures/tagged-destinations.nix { mkNodes = mkNixosNodes; };
  mkNixosNodes = import ./helpers/mk-nodes.nix { inherit crossConfig nixpkgs system; };
  contributionOrigin = [
    "sender `sender`"
    "receiver `receiver`"
    "destination `inventory.payload.value`"
    "fixtures/tagged-destinations.nix"
  ];
  inherit (nixpkgs) lib;
  tests = {
    nixos =
      let
        result = import ./fixtures/tagged-nixos.nix { inherit crossConfig nixpkgs system; };
      in
      {
        testPublication = {
          expr = result.publication;
          expected = {
            domain = "application.example";
            upstream = "http://192.0.2.10:8080";
          };
        };
        testProxyPass = {
          expr = result.proxyPass;
          expected = "http://192.0.2.10:8080";
        };
        testFirewallPort = {
          expr = builtins.elem 80 result.firewallPorts;
          expected = true;
        };
        testAssertions = {
          expr = builtins.all (builtins.all (value: value)) (builtins.attrValues result.assertions);
          expected = true;
        };
      };
    scalar = checkValue "contributed" {
      leafPath = [ ];
      tagOption = lib.mkOption {
        type = lib.types.str;
        description = "A scalar tag.";
      };
    };
    nested = checkValue "contributed" { tagOption = submoduleOption; };
    named = checkValue "contributed" {
      tagOption = lib.mkOption {
        type = lib.types.submodule (
          { name, ... }:
          {
            options.value = lib.mkOption {
              type = lib.types.str;
              default = "local";
              readOnly = name != "payload";
              description = "A field writable only under its original tag name.";
            };
          }
        );
        description = "A tag with name-dependent permissions.";
      };
    };
    namedEntry = checkValue "contributed" {
      leafPath = [
        "entries"
        "writable"
        "value"
      ];
      tagOption = lib.mkOption {
        type = lib.types.submodule {
          options.entries = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options.value = lib.mkOption {
                    type = lib.types.str;
                    default = "local";
                    readOnly = name != "writable";
                    description = "A field writable only in its named entry.";
                  };
                }
              )
            );
            default = { };
            description = "Named entries inside a tag.";
          };
        };
        description = "A tag containing named entries.";
      };
    };
    dottedTag = checkValue "contributed" {
      tagName = "app.example";
      tagOption = submoduleOption;
    };
    moduleTag = checkValue "contributed" {
      tagName = "_module";
      tagOption = submoduleOption;
    };
    crossConfigTag = checkValue "contributed" {
      tagName = "crossConfig";
      tagOption = submoduleOption;
    };
    emptyDeclarations = checkValue "contributed" {
      tagOption = submoduleOption // {
        declarations = [ ];
      };
    };
    receiverDeclared = checkValue "contributed" {
      tagOption = lib.mkOption {
        type = lib.types.submodule { };
        description = "A tag whose receiver declares its fields.";
      };
      receiverDefinitions = [
        {
          payload = { lib, ... }: {
            options.value = lib.mkOption {
              type = lib.types.str;
              description = "A receiver-owned declaration.";
            };
            config.value = lib.mkDefault "local";
          };
        }
      ];
    };
    receiverLocalPermissions = checkValue "contributed" {
      tagOption = import ./fixtures/tagged-permissions.nix { inherit lib; };
      receiverDefinitions = [ { payload.locked = false; } ];
    };
    freeform = checkValue "contributed" {
      leafPath = [ "extra" ];
      tagOption = lib.mkOption {
        type = lib.types.submodule { };
        description = "A tag with receiver-owned freeform fields.";
      };
      receiverDefinitions = [
        {
          payload = { lib, ... }: {
            _module.freeformType = lib.types.attrsOf lib.types.str;
            extra = lib.mkDefault "local";
          };
        }
      ];
    };
    tagDefault = checkValue "tag-default" {
      leafPath = [ ];
      tagOption = lib.mkOption {
        type = lib.types.str;
        default = "tag-default";
        description = "A tag-level default retained by disabled contributions.";
      };
      senderDefinitions = [ (lib.mkIf false (throw "Disabled default override was forced.")) ];
      receiverDefinitions = [ { payload = lib.mkIf false "unused"; } ];
    };
    ordinaryPriority = checkValue "contributed" {
      tagOption = submoduleOption;
      receiverDefinitions = [ { payload.value = lib.mkDefault "local"; } ];
    };
    defaultPriority = checkValue "local" {
      tagOption = submoduleOption;
      senderDefinitions = [ (lib.mkDefault "contributed") ];
      receiverDefinitions = [ { payload.value = "local"; } ];
    };
    forcedPriority = checkValue "contributed" {
      tagOption = submoduleOption;
      senderDefinitions = [ (lib.mkForce "contributed") ];
      receiverDefinitions = [ { payload.value = "local"; } ];
    };
    outerPriority = checkValue "local" {
      tagOption = submoduleOption;
      senderDefinitions = [ (lib.mkDefault "contributed") ];
      receiverDefinitions = [ (lib.mkForce { payload.value = "local"; }) ];
    };
    ordering = checkValue [ "first" "local" "last" ] {
      tagOption = submoduleOption // {
        type = lib.types.submodule {
          options.value = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Ordered definitions below a writable tag.";
          };
        };
      };
      senderDefinitions = [
        (lib.mkBefore [ "first" ])
        (lib.mkAfter [ "last" ])
      ];
      receiverDefinitions = [ { payload.value = [ "local" ]; } ];
    };
    conditions = checkValue "contributed" {
      tagOption = submoduleOption;
      senderDefinitions = [
        (lib.mkIf true "contributed")
        (lib.mkIf false (throw "Disabled tagged payload was evaluated."))
      ];
      receiverDefinitions = [ (lib.mkIf true { payload.value = lib.mkDefault "local"; }) ];
    };
    transportSelection =
      let
        nodes = mkNodes {
          optionPaths = [
            [
              "inventory"
              "payload"
              "value"
            ]
          ];
          modules = {
            sender.crossConfig.nodes = lib.mkMerge [
              (lib.mkDefault { unknown = throw "Discarded receiver was forced."; })
              (lib.mkForce {
                receiver = lib.mkIf true {
                  inventory.payload.value = "selected";
                };
              })
            ];
            receiver = relationModule;
          };
        };
      in
      {
        testSelectedValue = {
          expr = nodes.receiver.config.inventory.payload.value;
          expected = "selected";
        };
        testAssertions = {
          expr = checkAssertions nodes;
          expected = true;
        };
      };
    unusedAndDisabled =
      let
        inventoryModule = {
          options.inventory = lib.mkOption {
            type = lib.types.attrTag {
              payload = submoduleOption // {
                type = lib.types.submodule {
                  options = {
                    value = lib.mkOption {
                      type = lib.types.str;
                      default = "local";
                      description = "The local value retained by inactive contributions.";
                    };
                    locked = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      description = "An unused read-only child without a value.";
                    };
                  };
                };
              };
              locked = lib.mkOption {
                type = lib.types.str;
                readOnly = true;
                description = "An unused read-only tag without a value.";
              };
            };
            default.payload = { };
            description = "Inventory retaining unused and disabled registrations.";
          };
        };
        nodes = mkNodes {
          optionPaths = [
            [
              "inventory"
              "missing"
            ]
            [
              "inventory"
              "locked"
            ]
            [
              "inventory"
              "payload"
              "missing"
            ]
            [
              "inventory"
              "payload"
              "locked"
            ]
          ];
          modules = {
            idle = inventoryModule;
            receiver = inventoryModule;
            sender.crossConfig.nodes.receiver.inventory = {
              missing = lib.mkIf false (throw "Disabled missing tag was evaluated.");
              locked = lib.mkIf false (throw "Disabled read-only tag was evaluated.");
              payload.missing = lib.mkIf false (throw "Disabled missing child was evaluated.");
              payload.locked = lib.mkIf false (throw "Disabled read-only child was evaluated.");
            };
          };
        };
      in
      {
        testIdleValue = {
          expr = nodes.idle.config.inventory.payload.value;
          expected = "local";
        };
        testReceiverValue = {
          expr = nodes.receiver.config.inventory.payload.value;
          expected = "local";
        };
        testLockedTag = {
          expr = nodes.receiver.config.inventory ? locked;
          expected = false;
        };
        testMissingChild = {
          expr = nodes.receiver.config.inventory.payload ? missing;
          expected = false;
        };
        testAssertions = {
          expr = checkAssertions nodes;
          expected = true;
        };
      };
    conditionalSelf =
      let
        nodes = mkNodes {
          optionPaths = [
            [
              "inventory"
              "payload"
              "value"
            ]
          ];
          modules.alpha = { config, ... }: {
            imports = [ relationModule ];
            crossConfig.nodes.alpha.inventory.payload.value =
              lib.mkIf config.inventory.payload.enable "from-self";
          };
        };
      in
      {
        testSelfContribution = {
          expr = nodes.alpha.config.inventory.payload.value;
          expected = "from-self";
        };
        testAssertions = {
          expr = checkAssertions nodes;
          expected = true;
        };
      };
    reciprocal =
      let
        nodes = mkNodes {
          optionPaths = [
            [
              "inventory"
              "payload"
              "value"
            ]
          ];
          modules = {
            alpha = {
              imports = [ relationModule ];
              crossConfig.nodes.beta.inventory.payload.value = "from-alpha";
            };
            beta = {
              imports = [ relationModule ];
              crossConfig.nodes.alpha.inventory.payload.value = "from-beta";
            };
          };
        };
      in
      {
        testAlphaValue = {
          expr = nodes.alpha.config.inventory.payload.value;
          expected = "from-beta";
        };
        testBetaValue = {
          expr = nodes.beta.config.inventory.payload.value;
          expected = "from-alpha";
        };
        testAssertions = {
          expr = checkAssertions nodes;
          expected = true;
        };
      };
    lazyApply =
      let
        inherit
          (mkTaggedNodes {
            tagOption = submoduleOption // {
              apply = _: throw "Tag apply was forced during destination inspection.";
            };
          })
          nodes
          ;
      in
      # The assertions inspect the destination without asking for its final value.
      {
        testAssertions = {
          expr = checkAssertions nodes;
          expected = true;
        };
        testApplyFailure = {
          expr = nodes.receiver.config.inventory.payload;
          expectedError = {
            type = "ThrownError";
            msg = "Tag apply was forced during destination inspection\\.";
          };
        };
      };
  }
  //
    lib.mapAttrs
      (
        _: type:
        checkValue "contributed" {
          tagOption = lib.mkOption {
            inherit type;
            description = "A tag containing a wrapped submodule.";
          };
        }
      )
      {
        coerced = lib.types.coercedTo lib.types.str (value: { inherit value; }) submoduleOption.type;
        either = lib.types.either lib.types.str submoduleOption.type;
        nullable = lib.types.nullOr submoduleOption.type;
        unique = lib.types.uniq submoduleOption.type;
      };

  mkNodes = import ./helpers/mk-module-nodes.nix { inherit crossConfig lib; };
  mkTaggedNodes = import ./helpers/mk-tagged-nodes.nix { inherit lib mkNodes; };
  checkValue =
    expected: args:
    let
      inherit (mkTaggedNodes args) nodes path;
    in
    {
      testValue = {
        expr = lib.getAttrFromPath path nodes.receiver.config;
        inherit expected;
      };
      testAssertions = {
        expr = checkAssertions nodes;
        expected = true;
      };
    };
  submoduleOption = lib.mkOption {
    type = lib.types.submodule {
      options.value = lib.mkOption {
        type = lib.types.str;
        default = "local";
        description = "A writable field inside the tag.";
      };
    };
    description = "A writable submodule tag.";
  };
  relationModule = {
    options.inventory = lib.mkOption {
      type = lib.types.attrTag {
        payload = submoduleOption // {
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "the self contribution" // {
                default = true;
              };
              value = lib.mkOption {
                type = lib.types.str;
                default = "local";
                description = "A value exchanged between nodes.";
              };
            };
          };
        };
      };
      default.payload = { };
      description = "A tagged inventory shared by participating nodes.";
    };
  };
in
tests
// {
  testRejectsConflict = {
    expr = rejections.taggedConflict;
    expectedError = {
      type = "ThrownError";
      msg = "conflicting definition";
      trace = [ "conflicting definition" ] ++ contributionOrigin;
    };
  };
  testRejectsDefaultSource = {
    expr = rejections.taggedDefaultSource;
    expectedError = {
      type = "ThrownError";
      msg = "is not of type";
      trace = [
        "is not of type"
        "inventory.payload"
        "fixtures/tagged-default.nix"
      ];
    };
  };
  testRejectsIncompatible = {
    expr = rejections.taggedIncompatible;
    expectedError = {
      type = "ThrownError";
      msg = "is not of type";
      trace = [ "is not of type" ] ++ contributionOrigin;
    };
  };
  testRejectsInspectionDefinitionSource = {
    expr = rejections.taggedInspectionDefinitionSource;
    expectedError = {
      type = "ThrownError";
      msg = "is not of type";
      trace = [
        "is not of type"
        "inventory.payload.locked"
        "fixtures/tagged-invalid-local.nix"
      ];
    };
  };
  testRejectsMissingChild = {
    expr = rejections.taggedMissingChild;
    expectedError = {
      type = "ThrownError";
      msg = "missing destination";
      trace = [ "missing destination" ] ++ contributionOrigin;
    };
  };
  testRejectsMissingTag = {
    expr = rejections.taggedMissingTag;
    expectedError = {
      type = "ThrownError";
      msg = "missing destination";
      trace = [ "missing destination" ] ++ contributionOrigin;
    };
  };
  testRejectsReadOnlyChild = {
    expr = rejections.taggedReadOnlyChild;
    expectedError = {
      type = "ThrownError";
      msg = "read-only destination";
      trace = [ "read-only destination" ] ++ contributionOrigin;
    };
  };
  testRejectsReadOnlyCoerced = {
    expr = rejections.taggedReadOnlyCoerced;
    expectedError = {
      type = "ThrownError";
      msg = "read-only destination";
      trace = [ "read-only destination" ] ++ contributionOrigin;
    };
  };
  testRejectsReadOnlyEither = {
    expr = rejections.taggedReadOnlyEither;
    expectedError = {
      type = "ThrownError";
      msg = "read-only destination";
      trace = [ "read-only destination" ] ++ contributionOrigin;
    };
  };
  testRejectsReadOnlyLocal = {
    expr = rejections.taggedReadOnlyLocal;
    expectedError = {
      type = "ThrownError";
      msg = "read-only destination";
      trace = [ "read-only destination" ] ++ contributionOrigin;
    };
  };
  testRejectsReadOnlyName = {
    expr = rejections.taggedReadOnlyName;
    expectedError = {
      type = "ThrownError";
      msg = "read-only destination";
      trace = [ "read-only destination" ] ++ contributionOrigin;
    };
  };
  testRejectsReadOnlyNullable = {
    expr = rejections.taggedReadOnlyNullable;
    expectedError = {
      type = "ThrownError";
      msg = "read-only destination";
      trace = [ "read-only destination" ] ++ contributionOrigin;
    };
  };
  testRejectsReadOnlyTag = {
    expr = rejections.taggedReadOnlyTag;
    expectedError = {
      type = "ThrownError";
      msg = "read-only destination";
      trace = [ "read-only destination" ] ++ contributionOrigin;
    };
  };
  testRejectsReadOnlyUnique = {
    expr = rejections.taggedReadOnlyUnique;
    expectedError = {
      type = "ThrownError";
      msg = "read-only destination";
      trace = [ "read-only destination" ] ++ contributionOrigin;
    };
  };
  testRejectsValueCycle = {
    expr = import ./fixtures/tagged-value-cycle.nix { mkNodes = mkNixosNodes; };
    expectedError = {
      type = "EvalError";
      msg = "infinite recursion encountered";
    };
  };
}
