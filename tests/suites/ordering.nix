{ checkAssertions, mkNodes, ... }:
let
  optionPaths = [
    [
      "networking"
      "search"
    ]
  ];
  nodes = mkNodes {
    inherit optionPaths;
    modules = {
      alpha =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.networking.search = lib.mkMerge [
            (lib.mkAfter [ "after.example" ])
            (lib.mkOrder 250 [ "first.example" ])
            (lib.mkOrder 1250 [ "late.example" ])
          ];
        };
      beta =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.networking.search = lib.mkMerge [
            (lib.mkBefore [ "before.example" ])
            (lib.mkOrder 1750 [ "last.example" ])
          ];
        };
      receiver =
        { lib, ... }:
        {
          networking.search = lib.mkMerge [
            [ "local.example" ]
            (lib.mkOrder 750 [ "early-local.example" ])
          ];
        };
    };
  };
  forcedNodes = mkNodes {
    inherit optionPaths;
    modules = {
      alpha =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.networking.search = lib.mkMerge [
            (lib.mkForce (lib.mkBefore [ "alpha.example" ]))
            (lib.mkDefault (lib.mkOrder 1 [ "discarded-default.example" ]))
          ];
        };
      beta =
        { lib, ... }:
        {
          crossConfig.nodes.receiver.networking.search = lib.mkForce (lib.mkAfter [ "beta.example" ]);
        };
      receiver =
        { lib, ... }:
        {
          networking.search = lib.mkMerge [
            (lib.mkForce [ "local.example" ])
            (lib.mkOrder 1 [ "discarded-local.example" ])
          ];
        };
    };
  };
in
{
  testOrder = {
    expr = nodes.receiver.config.networking.search;
    expected = [
      "first.example"
      "before.example"
      "early-local.example"
      "local.example"
      "late.example"
      "after.example"
      "last.example"
    ];
  };
  testForcedOrder = {
    expr = forcedNodes.receiver.config.networking.search;
    expected = [
      "alpha.example"
      "local.example"
      "beta.example"
    ];
  };
  testAssertions = {
    expr = checkAssertions nodes;
    expected = true;
  };
  testForcedAssertions = {
    expr = checkAssertions forcedNodes;
    expected = true;
  };
}
