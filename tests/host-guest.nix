{
  checkAssertions,
  crossConfig,
  mkNodes,
}:
let
  optionPaths = [
    [
      "networking"
      "hosts"
    ]
  ];
  nodes = mkNodes {
    inherit optionPaths;
    extraNodes.guest.config = nodes.host.config.containers.application.config;
    modules = {
      host = {
        networking.hosts."192.0.2.20" = [ "host-local.example" ];
        crossConfig.nodes.guest.networking.hosts."192.0.2.10" = [
          "host-to-guest.example"
        ];
        containers.application.config = {
          imports = [
            crossConfig.nixosModules.default
          ];
          crossConfig = {
            name = "guest";
            inherit optionPaths;
            nodeCollection = nodes;
          };
          networking.hostName = "application-container";
          networking.hosts."192.0.2.10" = [ "guest-local.example" ];
          system.stateVersion = "26.05";
          crossConfig.nodes = {
            host.networking.hosts."192.0.2.20" = [
              "guest-to-parent.example"
            ];
            guest.networking.hosts."192.0.2.10" = [
              "guest-to-self.example"
            ];
            receiver.networking.hosts."192.0.2.20" = [
              "guest-to-host.example"
            ];
          };
        };
      };
      receiver = { };
    };
  };
in
{
  testContainer = {
    expr = nodes.guest.config.boot.isContainer;
    expected = true;
  };
  testGuestHostName = {
    expr = nodes.guest.config.networking.hostName;
    expected = "application-container";
  };
  testGuestContributions = {
    expr = builtins.sort builtins.lessThan nodes.guest.config.networking.hosts."192.0.2.10";
    expected = [
      "guest-local.example"
      "guest-to-self.example"
      "host-to-guest.example"
    ];
  };
  testParentContribution = {
    expr = builtins.sort builtins.lessThan nodes.host.config.networking.hosts."192.0.2.20";
    expected = [
      "guest-to-parent.example"
      "host-local.example"
    ];
  };
  testReceiverContribution = {
    expr = nodes.receiver.config.networking.hosts."192.0.2.20";
    expected = [
      "guest-to-host.example"
    ];
  };
  testAssertions = {
    expr = checkAssertions nodes;
    expected = true;
  };
}
