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
        crossConfig.nodes.guest.networking.hosts."192.0.2.10" = [
          "host-to-guest.example"
        ];
        containers.application.config = {
          imports = [
            (crossConfig.lib.mkModule {
              name = "guest";
              inherit nodes optionPaths;
            })
          ];
          networking.hostName = "application-container";
          system.stateVersion = "26.05";
          crossConfig.nodes.receiver.networking.hosts."192.0.2.20" = [
            "guest-to-host.example"
          ];
        };
      };
      receiver = { };
    };
  };
in
assert nodes.guest.config.boot.isContainer;
assert nodes.guest.config.networking.hostName == "application-container";
assert
  nodes.guest.config.networking.hosts."192.0.2.10" == [
    "host-to-guest.example"
  ];
assert
  nodes.receiver.config.networking.hosts."192.0.2.20" == [
    "guest-to-host.example"
  ];
assert checkAssertions nodes;
true
