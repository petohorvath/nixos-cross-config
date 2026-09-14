{ checkAssertions, mkNodes }:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "search"
      ]
    ];
    modules = {
      mapSender =
        { lib, ... }:
        {
          crossConfig.nodes = lib.mkMerge [
            (lib.mkDefault {
              mapReceiver.networking.search = [ "discarded.example" ];
              unselected.networking.search = [ "discarded.example" ];
            })
            (lib.mkForce {
              mapReceiver.networking.search = lib.mkAfter [ "selected.example" ];
            })
          ];
        };
      entrySender =
        { lib, ... }:
        {
          crossConfig.nodes.entryReceiver = lib.mkMerge [
            (lib.mkDefault { networking.search = [ "discarded.example" ]; })
            (lib.mkForce {
              networking.search = lib.mkBefore [ "selected.example" ];
            })
          ];
        };
      mapDefaultSender =
        { lib, ... }:
        {
          crossConfig.nodes = lib.mkDefault {
            defaults.networking.search = lib.mkBefore [ "map-default.example" ];
          };
        };
      entryDefaultSender =
        { lib, ... }:
        {
          crossConfig.nodes.defaults = lib.mkDefault {
            networking.search = lib.mkAfter [ "entry-default.example" ];
          };
        };
      mapReceiver.networking.search = [ "local.example" ];
      entryReceiver.networking.search = [ "local.example" ];
      defaults.networking.search = [ "local.example" ];
      unselected.networking.search = [ "local.example" ];
    };
  };
in
assert
  nodes.mapReceiver.config.networking.search == [
    "local.example"
    "selected.example"
  ];
assert
  nodes.entryReceiver.config.networking.search == [
    "selected.example"
    "local.example"
  ];
assert
  nodes.defaults.config.networking.search == [
    "map-default.example"
    "local.example"
    "entry-default.example"
  ];
assert nodes.unselected.config.networking.search == [ "local.example" ];
assert checkAssertions nodes;
true
