{ checkAssertions, mkNodes }:
let
  scenarios = {
    contributedDefault = {
      modules = {
        sender =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkDefault "contributed.example";
          };
        receiver.networking.domain = "receiver.example";
      };
      expected = "receiver.example";
    };
    receiverDefault = {
      modules = {
        sender.crossConfig.nodes.receiver.networking.domain = "contributed.example";
        receiver =
          { lib, ... }:
          {
            networking.domain = lib.mkDefault "receiver.example";
          };
      };
      expected = "contributed.example";
    };
    contributedForce = {
      modules = {
        alpha =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkForce "forced.example";
          };
        beta.crossConfig.nodes.receiver.networking.domain = "beta.example";
        receiver.networking.domain = "receiver.example";
      };
      expected = "forced.example";
    };
    receiverForce = {
      modules = {
        sender.imports = [
          { crossConfig.nodes.receiver.networking.domain = "first.example"; }
          { crossConfig.nodes.receiver.networking.domain = "second.example"; }
        ];
        receiver =
          { lib, ... }:
          {
            networking.domain = lib.mkForce "receiver.example";
          };
      };
      expected = "receiver.example";
    };
    customBeatsForce = {
      modules = {
        alpha =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkOverride 40 "custom.example";
          };
        beta =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkForce "beta.example";
          };
        receiver =
          { lib, ... }:
          {
            networking.domain = lib.mkForce "receiver.example";
          };
      };
      expected = "custom.example";
    };
    receiverCustomPriority = {
      modules = {
        alpha =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkOverride 75 "alpha.example";
          };
        beta =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkOverride 90 "beta.example";
          };
        receiver =
          { lib, ... }:
          {
            networking.domain = lib.mkOverride 60 "receiver.example";
          };
      };
      expected = "receiver.example";
    };
    customBeatsDefault = {
      modules = {
        alpha =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkOverride 900 "custom.example";
          };
        beta =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkDefault "beta.example";
          };
        receiver =
          { lib, ... }:
          {
            networking.domain = lib.mkDefault "receiver.example";
          };
      };
      expected = "custom.example";
    };
    contributedDefaultBeatsOptionDefault = {
      modules = {
        sender =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkDefault "contributed.example";
          };
        receiver = { };
      };
      expected = "contributed.example";
    };
    sameSenderPriorities = {
      modules = {
        sender =
          { lib, ... }:
          {
            crossConfig.nodes.receiver.networking.domain = lib.mkMerge [
              (lib.mkDefault "default.example")
              (lib.mkOverride 75 "custom.example")
              (lib.mkOverride 125 "weaker.example")
            ];
          };
        receiver.networking.domain = "receiver.example";
      };
      expected = "custom.example";
    };
  };
in
builtins.mapAttrs (
  _: scenario:
  let
    nodes = mkNodes {
      optionPaths = [
        [
          "networking"
          "domain"
        ]
      ];
      inherit (scenario) modules;
    };
  in
  assert nodes.receiver.config.networking.domain == scenario.expected;
  assert checkAssertions nodes;
  true
) scenarios
