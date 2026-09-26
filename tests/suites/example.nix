{ minimalExample, ... }:
let
  virtualHost = minimalExample.proxy.config.services.nginx.virtualHosts."app.example";
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
    expr = minimalExample.proxy.config.networking.hostName;
    expected = "proxy-container";
  };
  testSystemEvaluation = {
    expr = builtins.all (node: builtins.isString node.config.system.build.toplevel.drvPath) (
      builtins.attrValues minimalExample
    );
    expected = true;
  };
}
