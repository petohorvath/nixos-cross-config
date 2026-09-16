{ lib, mkNodes }:
{
  tagName ? "payload",
  leafPath ? [ "value" ],
  tagOption,
  senderDefinitions ? [ "contributed" ],
  receiverDefinitions ? [ ],
}:
let
  path = [
    "inventory"
    tagName
  ]
  ++ leafPath;
in
{
  inherit path;
  nodes = mkNodes {
    optionPaths = [ path ];
    modules = {
      sender = {
        _file = toString ./mk-tagged-nodes.nix;
        crossConfig.nodes.receiver = lib.setAttrByPath path (lib.mkMerge senderDefinitions);
      };
      receiver = {
        _file = toString ./mk-tagged-nodes.nix;
        options.inventory = lib.mkOption {
          type = lib.types.attrTag { ${tagName} = tagOption; };
          description = "A tagged receiver destination.";
        };
        config = lib.optionalAttrs (receiverDefinitions != [ ]) {
          inventory = lib.mkMerge receiverDefinitions;
        };
      };
    };
  };
}
