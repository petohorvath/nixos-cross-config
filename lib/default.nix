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
