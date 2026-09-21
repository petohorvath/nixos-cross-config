# Share collection settings through a NixOS module that callers import explicitly.
{ config, lib, ... }:
let
  flakeConfig = config;
  settings = import ./lib/settings.nix { inherit lib; };
in
{
  options.crossConfig = settings.options // {
    nodeCollection = settings.options.nodeCollection // {
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
        nodeCollection = lib.mkDefault flakeConfig.crossConfig.nodeCollection;
        optionPaths = lib.mkDefault flakeConfig.crossConfig.optionPaths;
      };
    };
}
