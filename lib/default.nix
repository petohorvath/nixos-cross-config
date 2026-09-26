{
  /*
    Keeps the constructor signature for existing consumers by adapting
    explicit arguments to the receiver-owned NixOS module.

    Inputs:
    - name: this node's identity within the node collection.
    - nodes: the caller-owned collection of evaluated nodes, each exposing
      `.config`.
    - optionPaths: the shared list of allowed destination paths.

    Returns a NixOS module that imports `nixos/module.nix` and defines the
    matching `crossConfig` settings, using the receiver's `lib`.
  */
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
