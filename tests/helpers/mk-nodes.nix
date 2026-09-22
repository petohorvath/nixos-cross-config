{
  crossConfig,
  nixpkgs,
  system,
}:
{
  extraNodes ? { },
  optionPaths,
  modules,
}:
let
  nodes =
    builtins.mapAttrs (
      name: module:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          crossConfig.nixosModules.default
          {
            crossConfig = {
              inherit name optionPaths;
              nodeConfigurations = nodes;
            };
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
      }
    ) modules
    // extraNodes;
in
nodes
