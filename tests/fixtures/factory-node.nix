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
    description = ''
      Contributions to a nested attribute whose name is reserved at the root.
    '';
  };
in
{
  options = {
    inventory = {
      _module = valuesOption;
      crossConfig = valuesOption;
      identity = lib.mkOption {
        type = lib.types.str;
        description = ''
          The collection identity supplied by the node constructor.
        '';
      };
      observedArguments = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          Ordinary receiver module arguments that also name factory arguments.
        '';
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
    crossConfig.contributions.${receiver}.inventory = {
      values = lib.mkBefore [ "from-${config.inventory.identity}-${ordinaryArgument}" ];
      crossConfig = [ "from-${config.inventory.identity}" ];
      _module = [ "from-${config.inventory.identity}" ];
    };
  };
}
