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
{
  testProxyPass = {
    expr = virtualHost.locations."/".proxyPass;
    expected = "http://192.0.2.10:8080";
  };
  testAliases = {
    expr = virtualHost.serverAliases;
    expected = [ "www.app.example" ];
  };
  testHostName = {
    expr = nodes.proxy.config.networking.hostName;
    expected = "proxy-container";
  };
  testSystemEvaluation = {
    expr = builtins.all (node: builtins.isString node.config.system.build.toplevel.drvPath) (
      builtins.attrValues nodes
    );
    expected = true;
  };
}
