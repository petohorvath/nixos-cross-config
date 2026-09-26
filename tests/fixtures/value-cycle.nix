{ mkNodes }:
let
  nodes = mkNodes {
    optionPaths = [
      [
        "networking"
        "domain"
      ]
    ];
    modules = {
      alpha =
        { config, ... }:
        {
          crossConfig.nodes.beta.networking.domain = config.networking.domain;
        };
      beta =
        { config, ... }:
        {
          crossConfig.nodes.alpha.networking.domain = config.networking.domain;
        };
    };
  };
in
builtins.mapAttrs (_: node: node.config.networking.domain) nodes
