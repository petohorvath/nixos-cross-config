{ allAssertionsPass, mkNodes, ... }:
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
          crossConfig.contributions = lib.mkMerge [
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
          crossConfig.contributions.entryReceiver = lib.mkMerge [
            (lib.mkDefault { networking.search = [ "discarded.example" ]; })
            (lib.mkForce {
              networking.search = lib.mkBefore [ "selected.example" ];
            })
          ];
        };
      mapDefaultSender =
        { lib, ... }:
        {
          crossConfig.contributions = lib.mkDefault {
            defaults.networking.search = lib.mkBefore [ "map-default.example" ];
          };
        };
      entryDefaultSender =
        { lib, ... }:
        {
          crossConfig.contributions.defaults = lib.mkDefault {
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
{
  testMapPriority = {
    expr = nodes.mapReceiver.config.networking.search;
    expected = [
      "local.example"
      "selected.example"
    ];
  };
  testEntryPriority = {
    expr = nodes.entryReceiver.config.networking.search;
    expected = [
      "selected.example"
      "local.example"
    ];
  };
  testDefaults = {
    expr = nodes.defaults.config.networking.search;
    expected = [
      "map-default.example"
      "local.example"
      "entry-default.example"
    ];
  };
  testUnselected = {
    expr = nodes.unselected.config.networking.search;
    expected = [ "local.example" ];
  };
  testAssertions = {
    expr = allAssertionsPass nodes;
    expected = true;
  };
}
