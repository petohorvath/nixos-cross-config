# Adapt explicit collection arguments to the receiver-owned NixOS module.
{
  mkModule =
    {
      name,
      nodes,
      optionPaths,
    }:
    { lib, ... }:
    lib.setDefaultModuleLocation ./default.nix {
      imports = [ ../nixos/module.nix ];
      crossConfig = {
        inherit name optionPaths;
        nodeConfigurations = nodes;
      };
    };
}
