/*
  Builds a caller-owned collection of two NixOS container configurations.
  The application contributes nginx settings to the proxy's existing options.
*/
{
  crossConfig,
  nixpkgs,
  system ? "x86_64-linux",
}:
let
  sharedSettings = {
    imports = [ crossConfig.nixosModules.default ];
    crossConfig = {
      nodeCollection = nodes;
      optionPaths = [
        [
          "services"
          "nginx"
          "virtualHosts"
        ]
      ];
    };
  };
  modules = {
    application.crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
      locations."/".proxyPass = "http://192.0.2.10:8080";
    };
    proxy.services.nginx = {
      enable = true;
      virtualHosts."app.example".serverAliases = [ "www.app.example" ];
    };
  };
  nodes = builtins.mapAttrs (
    name: module:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        sharedSettings
        {
          crossConfig.name = name;
          boot.isContainer = true;
          networking.hostName = "${name}-container";
          system.stateVersion = "26.05";
        }
        module
      ];
    }
  ) modules;
in
nodes
