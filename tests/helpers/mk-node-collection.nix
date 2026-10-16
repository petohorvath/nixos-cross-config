# Build a self-referential node collection from node modules keyed by node
# identity. The selected settings adapter supplies each node's identity, the
# collection, and the shared option paths.
{
  crossConfig,
  evaluateModules,
  lib,
  system,
}:
{
  optionPaths,
  modules,
  # `nixos` builds NixOS systems; `modules` evaluates only the node modules.
  evaluator ? "nixos",
  # `primary` uses `nixosModules.default`; `compatibility` uses `lib.mkModule`.
  adapter ? "primary",
  specialArgs ? _: { },
  # Collection members that are not built here, such as guests.
  extraNodes ? { },
}:
let
  select =
    kind: choices: choice:
    choices.${choice} or (throw "mkNodeCollection: unknown ${kind} `${choice}`.");

  adapterModule = select "adapter" {
    primary = name: {
      imports = [ crossConfig.nixosModules.default ];
      crossConfig = {
        inherit name optionPaths;
        nodeConfigurations = nodes;
      };
    };
    compatibility =
      name:
      crossConfig.lib.mkModule {
        inherit name nodes optionPaths;
      };
  } adapter;

  evaluate = select "evaluator" {
    nixos =
      name: module:
      lib.nixosSystem {
        inherit system;
        specialArgs = specialArgs name;
        modules = [
          (adapterModule name)
          {
            networking.hostName = "${name}-hostname";
            system.stateVersion = "26.05";
            boot.loader.grub.enable = false;
            fileSystems."/" = {
              device = "/dev/disk/by-label/nixos";
              fsType = "ext4";
            };
          }
          module
        ];
      };
    modules =
      name: module:
      evaluateModules {
        specialArgs = specialArgs name;
        modules = [
          (adapterModule name)
          module
        ];
      };
  } evaluator;

  nodes = lib.mapAttrs evaluate modules // extraNodes;
in
nodes
