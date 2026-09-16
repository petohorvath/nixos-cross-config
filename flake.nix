{
  description = "Configuration contributions between caller-owned NixOS nodes";

  outputs = _: {
    lib.mkModule =
      {
        name,
        nodes,
        optionPaths,
      }:
      { lib, ... }:
      # Match importApply without adding an input: lib belongs to the receiver.
      lib.setDefaultModuleLocation ./lib/mk-module.nix (
        import ./lib/mk-module.nix { inherit name nodes optionPaths; }
      );
  };
}
