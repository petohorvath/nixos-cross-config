{ nixpkgs }:
let
  inherit (nixpkgs) lib;
  crossConfig = (import ../flake.nix).outputs { };
  nodes = {
    alpha = mkNode "alpha" "beta";
    beta = mkNode "beta" "alpha";
  };
  mkNode =
    name: receiver:
    lib.evalModules {
      specialArgs.lib = lib // {
        mkOption = arguments: lib.mkOption arguments // { receiverLibrary = name; };
      };
      modules = [
        crossConfig.nixosModules.default
        {
          options = {
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
              description = "Assertions emitted by participating modules.";
            };
            inventory.values = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Received and local inventory values.";
            };
          };
          config = {
            crossConfig = {
              inherit name;
              nodeCollection = nodes;
              optionPaths = [
                [
                  "inventory"
                  "values"
                ]
              ];
              nodes.${receiver}.inventory.values = lib.mkBefore [ "from-${name}" ];
            };
            inventory.values = [ "local-${name}" ];
          };
        }
      ];
    };
in
assert
  nodes.alpha.config.inventory.values == [
    "from-beta"
    "local-alpha"
  ];
assert
  nodes.beta.config.inventory.values == [
    "from-alpha"
    "local-beta"
  ];
assert nodes.alpha.options.crossConfig.nodes.receiverLibrary == "alpha";
assert nodes.beta.options.crossConfig.nodes.receiverLibrary == "beta";
assert builtins.all (node: builtins.all (entry: entry.assertion) node.config.assertions) (
  builtins.attrValues nodes
);
true
