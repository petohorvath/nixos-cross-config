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
{
  options.inventory = {
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
    crossConfig.nodes.${receiver}.inventory.values = lib.mkBefore [
      "from-${config.inventory.identity}-${ordinaryArgument}"
    ];
  };
}
