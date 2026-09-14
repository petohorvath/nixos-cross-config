{
  crossConfig,
  nixpkgs,
  system,
}:
let
  nodes = import ../examples/minimal.nix {
    inherit crossConfig nixpkgs system;
  };
  virtualHost = nodes.proxy.config.services.nginx.virtualHosts."app.example";
in
assert virtualHost.locations."/".proxyPass == "http://192.0.2.10:8080";
assert virtualHost.serverAliases == [ "www.app.example" ];
assert nodes.proxy.config.networking.hostName == "proxy-container";
assert builtins.all (node: builtins.isString node.config.system.build.toplevel.drvPath) (
  builtins.attrValues nodes
);
true
