/*
  Shares collection settings at flake scope. The caller constructs both nodes
  and explicitly imports the configured NixOS module into each one.
*/
{
  crossConfig,
  flakeParts,
  nixpkgs,
  system ? "x86_64-linux",
}:
flakeParts.lib.mkFlake { inputs.self.outPath = ../.; } (
  { config, ... }:
  {
    imports = [ crossConfig.flakeModules.default ];
    systems = [ ];
    crossConfig.optionPaths = [
      [
        "services"
        "nginx"
        "virtualHosts"
      ]
    ];
    flake.nixosConfigurations =
      builtins.mapAttrs
        (
          name: module:
          nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              config.flake.nixosModules.crossConfig
              {
                crossConfig.name = name;
                boot.isContainer = true;
                networking.hostName = "${name}-container";
                system.stateVersion = "26.05";
              }
              module
            ];
          }
        )
        {
          application.crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
            locations."/".proxyPass = "http://192.0.2.10:8080";
          };
          proxy.services.nginx = {
            enable = true;
            virtualHosts."app.example".serverAliases = [ "www.app.example" ];
          };
        };
  }
)
