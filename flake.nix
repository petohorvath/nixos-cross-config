{
  description = "Configuration contributions between caller-owned NixOS nodes";

  outputs = _: {
    lib.mkModule = import ./lib/mk-module.nix;
  };
}
