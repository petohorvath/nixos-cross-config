/*
  Contributes definitions between caller-owned NixOS nodes. Each participant
  supplies crossConfig.name, crossConfig.nodeConfigurations, and
  crossConfig.optionPaths.
*/
{
  config,
  extendModules,
  lib,
  options,
  specialArgs,
  ...
}:
let
  cfg = config.crossConfig;

  /*
    Path errors should remain useful even when the required node name is
    missing.
  */
  nodeNameForErrors = if options.crossConfig.name.isDefined then cfg.name else null;
  settings = import ../lib/settings.nix {
    inherit lib;
    nodeName = nodeNameForErrors;
  };

  outgoingOption = import ../lib/outgoing-option.nix {
    inherit lib;
    inherit (cfg) name optionPaths;
  };

  inspectionPaths = specialArgs.__nixosCrossConfigInspectPaths or [ ];
  isInspectingDestinations = inspectionPaths != [ ];
  receiving = import ../lib/receiving.nix {
    inherit
      extendModules
      inspectionPaths
      lib
      options
      ;
    inherit (cfg) name nodeConfigurations optionPaths;
    inherit (settings) reservedRoots;
  };
  inherit (receiving) destinationAssertions receivedConfig;

  mkReceiverAssertion = receiver: contribution: {
    assertion = builtins.seq contribution (builtins.hasAttr receiver cfg.nodeConfigurations);
    message = "nixos-cross-config: sender `${cfg.name}` " + "targets unknown receiver `${receiver}`.";
  };
  receiverAssertions = lib.mapAttrsToList mkReceiverAssertion cfg.nodes;

  # Required settings must also be checked on idle nodes with no paths.
  assertions = builtins.seq cfg.name (
    builtins.seq cfg.nodeConfigurations (destinationAssertions ++ receiverAssertions)
  );
in
{
  options.crossConfig = settings.options // {
    name = lib.mkOption {
      type = lib.types.str;
      description = ''
        Required node identity within the caller-owned node collection,
        independent of the hostname.
      '';
    };
    nodes = outgoingOption;
  };

  config = lib.mkMerge [
    receivedConfig
    {
      /*
        Inspection checks local declarations; validate contributions only in the
        main evaluation.
      */
      assertions = lib.optionals (!isInspectingDestinations) assertions;
    }
  ];
}
