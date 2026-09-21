{
  config,
  lib,
  name,
  nodes,
  optionPaths,
  ordinaryArgument,
  receiver,
  ...
}:
let
  valuesOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Contributions beneath a root also used by the module itself.";
  };
in
{
  options = {
    _module.values = valuesOption;
    crossConfig.values = valuesOption;
    inventory = {
      identity = lib.mkOption {
        type = lib.types.str;
        description = "The collection identity supplied by the node constructor.";
      };
      observedArguments = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Ordinary receiver module arguments that also name factory arguments.";
      };
      values = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Contributed and receiver-local values.";
      };
    };
  };
  config = {
    inventory = {
      observedArguments = [
        name
        nodes.marker
        (lib.concatStringsSep "." (builtins.head optionPaths))
        ordinaryArgument
      ];
      values = [ "local-${config.inventory.identity}-${ordinaryArgument}" ];
    };
    crossConfig.nodes.${receiver} = {
      inventory.values = lib.mkBefore [ "from-${config.inventory.identity}-${ordinaryArgument}" ];
      crossConfig.values = [ "from-${config.inventory.identity}" ];
      _module.values = [ "from-${config.inventory.identity}" ];
    };
  };
}
