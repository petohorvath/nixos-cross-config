{
  crossConfig,
  nixpkgs,
  count,
}:
let
  results = builtins.genList run count;
  inherit (nixpkgs) lib;
  mkNodes = import ../../tests/fixtures/mk-module-nodes.nix { inherit crossConfig lib; };
  run =
    index:
    let
      nodes = mkNodes {
        optionPaths = [
          [
            "inventory"
            "payload"
            "value"
          ]
        ];
        modules = {
          sender.crossConfig.nodes.receiver.inventory.payload.value = "contributed-${toString index}";
          receiver.options.inventory = lib.mkOption {
            type = lib.types.attrTag {
              payload = lib.mkOption {
                type = lib.types.submodule (
                  { name, ... }: {
                    options.value = lib.mkOption {
                      type = lib.types.str;
                      default = "local";
                      readOnly = name != "payload";
                      description = "A field writable under its original tag name.";
                    };
                  }
                );
                description = "A writable tagged submodule.";
              };
            };
            default.payload = { };
            description = "A tagged receiver inventory.";
          };
        };
      };
    in
    {
      value = nodes.receiver.config.inventory.payload.value;
      assertions = lib.mapAttrs (_: node: map (entry: entry.assertion) node.config.assertions) nodes;
    };
in
results
