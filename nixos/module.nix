/*
  Contributes definitions between caller-owned NixOS nodes. Each participant
  supplies crossConfig.name, crossConfig.nodeCollection, and crossConfig.optionPaths.
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
  inherit (config.crossConfig) name optionPaths;
  nodes = config.crossConfig.nodeCollection;
  inspectionPaths = specialArgs.__nixosCrossConfigInspectPaths or [ ];
  isInspectingDestinations = inspectionPaths != [ ];
  settings = import ../lib/settings.nix {
    inherit lib;
    nodeName = if options.crossConfig.name.isDefined then name else null;
  };

  outgoingDefinitions =
    receiver: contribution:
    builtins.addErrorContext "while evaluating contributions from sender `${name}` to receiver `${receiver}`:" contribution._definitions;

  contributionType = import ../lib/contribution-type.nix { inherit lib optionPaths; };

  receiving = import ../lib/receiving.nix {
    inherit
      extendModules
      inspectionPaths
      lib
      name
      nodes
      optionPaths
      options
      ;
    inherit (settings) reservedRoots;
  };

  # Required settings must also be checked on idle nodes with no paths.
  assertions = builtins.seq name (
    builtins.seq nodes (
      receiving.assertions ++ lib.mapAttrsToList mkReceiverAssertion config.crossConfig.nodes
    )
  );

  mkReceiverAssertion = receiver: contribution: {
    assertion = builtins.seq contribution (builtins.hasAttr receiver nodes);
    message = "nixos-cross-config: sender `${name}` targets unknown receiver `${receiver}`.";
  };
in
{
  options.crossConfig = settings.options // {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Required node identity within the caller-owned node collection, independent of the hostname.";
    };
    nodes = lib.mkOption {
      type = lib.types.attrsOf contributionType;
      default = { };
      description = "Configuration contributions indexed by receiver node identity.";
      apply = lib.mapAttrs outgoingDefinitions;
    };
  };

  config = lib.mkMerge [
    receiving.definitions
    {
      # Inspection checks local declarations; validate contributions only in the main evaluation.
      assertions = lib.optionals (!isInspectingDestinations) assertions;
    }
  ];
}
