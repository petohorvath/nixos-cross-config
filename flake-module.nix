# Share collection settings through a NixOS module that callers import explicitly.
{ config, lib, ... }:
let
  cfg = config.crossConfig;
  settings = import ./lib/settings.nix { inherit lib; };
in
{
  options.crossConfig = settings.options // {
    nodeConfigurations = settings.options.nodeConfigurations // {
      default = config.flake.nixosConfigurations;
      defaultText = lib.literalExpression "config.flake.nixosConfigurations";
      description = "Opaque collection of caller-owned nodes exposing .config, shared by all participants. Defaults lazily to the consumer's NixOS configurations.";
    };
  };

  config.flake.nixosModules.crossConfig =
    { lib, ... }:
    {
      imports = [ ./nixos/module.nix ];
      crossConfig = {
        nodeConfigurations = lib.mkDefault cfg.nodeConfigurations;
        optionPaths = lib.mkDefault cfg.optionPaths;
      };
    };
}
