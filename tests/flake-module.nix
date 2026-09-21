{
  checkAssertions,
  crossConfig,
  flakeParts,
  nixpkgs,
  system,
}:
let
  inherit (nixpkgs) lib;
  valuePath = [
    "inventory"
    "values"
  ];
  literalPath = [
    "inventory"
    "literal.values"
  ];
  mkConsumer =
    sharedModules: nodeModule:
    flakeParts.lib.mkFlake { inputs.self.outPath = ../.; } (
      { config, ... }:
      {
        imports = [ crossConfig.flakeModules.default ] ++ sharedModules;
        systems = [ ];
        flake.nixosConfigurations = lib.genAttrs [ "alpha" "beta" ] (
          name: mkNode config.flake.nixosModules.crossConfig name nodeModule
        );
      }
    );
  mkNode =
    configuredModule: name: nodeModule:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs.lib = lib // {
        mkOption = arguments: lib.mkOption arguments // { receiverLibrary = name; };
      };
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
  reciprocal = { config, lib, ... }: {
    crossConfig.nodes.${
      if config.crossConfig.name == "alpha" then "beta" else "alpha"
    }.inventory.values =
      lib.mkBefore [ "from-${config.crossConfig.name}" ];
  };
  checkPair =
    consumer: paths:
    let
      nodes = consumer.nixosConfigurations;
    in
    assert
      nodes.alpha.config.inventory.values == [
        "from-beta"
        "local-alpha"
      ];
    assert
      nodes.beta.config.inventory.values == [
        "from-alpha"
        "local-beta"
      ];
    assert builtins.all (node: node.config.crossConfig.optionPaths == paths) (
      builtins.attrValues nodes
    );
    assert checkAssertions nodes;
    true;
  defaultConsumer = mkConsumer [ { crossConfig.optionPaths = [ valuePath ]; } ] reciprocal;
  mergedConsumer =
    mkConsumer
      [
        {
          crossConfig.optionPaths = lib.mkBefore [
            valuePath
            literalPath
          ];
        }
        {
          crossConfig.optionPaths = lib.mkAfter [
            literalPath
            valuePath
          ];
        }
      ]
      {
        imports = [ reciprocal ];
        crossConfig.nodes.alpha.inventory."literal.values" = [ "literal" ];
      };
  emptyConsumer = mkConsumer [
    {
      crossConfig = {
        optionPaths = [ ];
        nodeCollection.unused = throw "An unused node in the opaque collection was forced.";
      };
    }
  ] { };
  overriddenConsumer =
    mkConsumer
      [
        {
          crossConfig = {
            optionPaths = [ literalPath ];
            nodeCollection = throw "The overridden flake-level collection was forced.";
          };
        }
      ]
      {
        imports = [ reciprocal ];
        crossConfig = {
          optionPaths = [ valuePath ];
          nodeCollection = overriddenConsumer.nixosConfigurations;
        };
      };
  explicitConsumer = flakeParts.lib.mkFlake { inputs.self.outPath = ../.; } (
    { config, ... }:
    let
      nodes = {
        alpha = mkNode config.flake.nixosModules.crossConfig "alpha" {
          crossConfig.nodes.guest.inventory.values = lib.mkBefore [ "from-alpha" ];
        };
        guest = mkNode config.flake.nixosModules.crossConfig "guest" {
          crossConfig.nodes.alpha.inventory.values = lib.mkBefore [ "from-guest" ];
        };
      };
    in
    {
      imports = [ crossConfig.flakeModules.default ];
      systems = [ ];
      crossConfig = {
        nodeCollection = nodes;
        optionPaths = [ valuePath ];
      };
      flake = {
        inherit (nodes) guest;
        nixosConfigurations = {
          inherit (nodes) alpha;
          unrelated = throw "A node outside the selected collection was forced.";
        };
      };
    }
  );
in
{
  example =
    let
      consumer = import ../examples/flake-parts.nix {
        inherit
          crossConfig
          flakeParts
          nixpkgs
          system
          ;
      };
      nodes = consumer.nixosConfigurations;
      virtualHost = nodes.proxy.config.services.nginx.virtualHosts."app.example";
    in
    assert virtualHost.locations."/".proxyPass == "http://192.0.2.10:8080";
    assert virtualHost.serverAliases == [ "www.app.example" ];
    assert checkAssertions nodes;
    true;
  defaultCollection = checkPair defaultConsumer [ valuePath ];
  systemEvaluation =
    assert builtins.all (node: builtins.isString node.config.system.build.toplevel.drvPath) (
      builtins.attrValues defaultConsumer.nixosConfigurations
    );
    true;
  mergedRegistrations =
    assert checkPair mergedConsumer [
      valuePath
      literalPath
    ];
    assert
      mergedConsumer.nixosConfigurations.alpha.config.inventory."literal.values" == [
        "literal"
        "literal"
      ];
    true;
  sharedRegistrations =
    let
      evaluation = flakeParts.lib.evalFlakeModule { inputs.self.outPath = ../.; } {
        imports = [
          crossConfig.flakeModules.default
          {
            crossConfig.optionPaths = lib.mkBefore [
              valuePath
              literalPath
            ];
          }
          {
            crossConfig.optionPaths = lib.mkAfter [
              literalPath
              valuePath
              [
                "inventory"
                "_module"
              ]
              [
                "inventory"
                "crossConfig"
              ]
            ];
          }
        ];
        systems = [ ];
      };
    in
    assert
      evaluation.config.crossConfig.optionPaths == [
        valuePath
        literalPath
        [
          "inventory"
          "_module"
        ]
        [
          "inventory"
          "crossConfig"
        ]
      ];
    true;
  explicitImports =
    let
      consumer = flakeParts.lib.mkFlake { inputs.self.outPath = ../.; } {
        imports = [ crossConfig.flakeModules.default ];
        systems = [ ];
        crossConfig.optionPaths = [ ];
        flake.nixosConfigurations.untouched = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            {
              boot.isContainer = true;
              system.stateVersion = "26.05";
            }
          ];
        };
      };
    in
    assert !(consumer.nixosConfigurations.untouched.options ? crossConfig);
    assert checkAssertions consumer.nixosConfigurations;
    true;
  explicitCollection =
    let
      nodes = {
        inherit (explicitConsumer.nixosConfigurations) alpha;
        inherit (explicitConsumer) guest;
      };
    in
    assert !(explicitConsumer.nixosConfigurations ? guest);
    assert
      nodes.alpha.config.inventory.values == [
        "from-guest"
        "local-alpha"
      ];
    assert
      nodes.guest.config.inventory.values == [
        "from-alpha"
        "local-guest"
      ];
    assert checkAssertions nodes;
    true;
  emptyRegistrations =
    assert builtins.all (
      node:
      node.config.crossConfig.optionPaths == [ ]
      && node.config.crossConfig.nodes == { }
      && builtins.attrNames node.config.crossConfig.nodeCollection == [ "unused" ]
    ) (builtins.attrValues emptyConsumer.nixosConfigurations);
    assert checkAssertions emptyConsumer.nixosConfigurations;
    true;
  sharedDefaults = checkPair (mkConsumer [
    { crossConfig.optionPaths = lib.mkDefault (throw "Overridden default registrations were forced."); }
    { crossConfig.optionPaths = [ valuePath ]; }
  ] reciprocal) [ valuePath ];
  sharedForce = checkPair (mkConsumer [
    { crossConfig.optionPaths = [ [ "crossConfig" ] ]; }
    { crossConfig.optionPaths = lib.mkForce [ valuePath ]; }
  ] reciprocal) [ valuePath ];
  nodeDefaults = checkPair overriddenConsumer [ valuePath ];
  receiverLibrary =
    assert builtins.all
      (
        name:
        defaultConsumer.nixosConfigurations.${name}.options.crossConfig.nodes.receiverLibrary == name
        &&
          defaultConsumer.nixosConfigurations.${name}.options.crossConfig.optionPaths.receiverLibrary == name
      )
      [
        "alpha"
        "beta"
      ];
    true;
  plainImport =
    let
      exports = (import ../flake.nix).outputs {
        nixpkgs = throw "Export access forced the development nixpkgs input.";
        flake-parts = throw "Export access forced the development flake-parts input.";
      };
      consumer = flakeParts.lib.mkFlake { inputs.self.outPath = ../.; } {
        imports = [ exports.flakeModules.default ];
        systems = [ ];
        crossConfig.optionPaths = [ ];
      };
      node = mkNode consumer.nixosModules.crossConfig "idle" { };
    in
    assert builtins.isFunction exports.lib.mkModule;
    assert builtins.isFunction (import exports.nixosModules.default);
    assert node.config.crossConfig.optionPaths == [ ];
    assert builtins.all (entry: entry.assertion) node.config.assertions;
    true;
}
