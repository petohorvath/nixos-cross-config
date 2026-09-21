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
  module = {
    options.crossConfig = settings.options // {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Required node identity within the caller-owned node collection, independent of the hostname.";
      };
      nodes = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule mkContributionModule);
        default = { };
        description = "Configuration contributions indexed by receiver node identity.";
        apply = lib.mapAttrs (
          receiver: contribution:
          let
            context = "while evaluating contributions from sender `${name}` to receiver `${receiver}`:";
          in
          builtins.addErrorContext context contribution._definitions
        );
      };
    };

    config = lib.mkMerge [
      # Declarations fix the outer names before any allowed paths are inspected.
      (lib.mapAttrs mkReceivingNamespace (builtins.removeAttrs options settings.reservedRoots))
      (lib.optionalAttrs (inspectionPaths == [ ]) {
        # Required settings must also be checked on idle nodes with no paths.
        assertions = builtins.seq name (
          builtins.seq nodes (
            map mkDestinationAssertion optionPaths
            ++ lib.mapAttrsToList (receiver: contribution: {
              assertion = builtins.seq contribution (builtins.hasAttr receiver nodes);
              message = "nixos-cross-config: sender `${name}` targets unknown receiver `${receiver}`.";
            }) config.crossConfig.nodes
          )
        );
      })
    ];
  };

  inherit (config.crossConfig) name optionPaths;
  nodes = config.crossConfig.nodeCollection;
  inspectionPaths = specialArgs.__nixosCrossConfigInspectPaths or [ ];
  settings = import ../lib/settings.nix {
    inherit lib;
    nodeName = if options.crossConfig.name.isDefined then name else null;
  };

  mkContributionModule =
    { options, ... }:
    {
      options =
        mkPathAttrs (
          path:
          lib.mkOption {
            type = lib.types.raw;
            description = "Definitions contributed to ${lib.showOption path}.";
          }
        )
        // {
          _definitions = lib.mkOption {
            type = lib.types.raw;
            internal = true;
            visible = false;
            readOnly = true;
            description = "Outgoing definitions before the receiving type merges them.";
            # Inspect definitions without forcing a merge in the sender.
            default = mkPathAttrs (path: restoreDefinitionProperties (lib.getAttrFromPath path options));
          };
        };
    };

  mkReceivingNamespace =
    root: _:
    lib.pipe optionPaths [
      (builtins.filter (path: builtins.head path == root && !(builtins.elem path inspectionPaths)))
      (lib.concatMap (
        path:
        let
          definition = mkReceivingDefinition path;
        in
        lib.optional (builtins.hasAttr root definition) definition.${root}
      ))
      lib.mkMerge
    ];

  mkReceivingDefinition =
    path:
    let
      definitions = collectDefinitions path;
      mkPath =
        remaining: declarations:
        if remaining == [ ] then
          { }
        else
          let
            segment = builtins.head remaining;
            rest = builtins.tail remaining;
            destination = declarations.${segment} or null;
            option = findReceivingOption path;
          in
          lib.optionalAttrs
            (destination != null && (!lib.isOption destination || !(destination.readOnly or false)))
            {
              ${segment} =
                if lib.isOption destination then
                  if rest == [ ] then
                    lib.mkMerge definitions
                  else
                    # Inspect instances only inside their declared writable option.
                    lib.mkMerge (
                      lib.optional (option != null && !(option.readOnly or false)) (
                        lib.setAttrByPath rest (lib.mkMerge definitions)
                      )
                    )
                else
                  mkPath rest destination;
            };
    in
    # Keep declaration inspection below its namespace so module arguments resolve.
    mkPath path options;

  mkDestinationAssertion =
    path:
    let
      option = findReceivingOption path;
      definitions = collectDefinitions path;
      reason = if option == null then "missing" else "read-only";
    in
    {
      assertion = definitions == [ ] || (option != null && !(option.readOnly or false));
      message = ''
        nixos-cross-config: receiver `${name}` has a ${reason} destination `${lib.showOption path}`.
        Contributions: ${lib.concatMapStringsSep ", " (definition: definition.file) definitions}
      '';
    };

  findReceivingOption = import ../lib/destination-inspection.nix {
    inherit
      extendModules
      inspectionPaths
      lib
      options
      ;
  };

  collectDefinitions =
    path:
    lib.pipe nodes [
      (lib.mapAttrsToList (
        sender: node:
        map (
          definition:
          lib.mkDefinition {
            file =
              definition.file
              + " (sender `${sender}`, receiver `${name}`,"
              + " destination `${lib.showOption path}`)";
            inherit (definition) value;
          }
        ) (lib.attrByPath path [ ] (node.config.crossConfig.nodes.${name} or { }))
      ))
      lib.concatLists
    ];

  mkPathAttrs =
    getValue:
    lib.pipe optionPaths [
      (map (path: lib.setAttrByPath path (getValue path)))
      (lib.foldl' lib.recursiveUpdate { })
    ];

  restoreDefinitionProperties = import ../lib/restore-definition-properties.nix { inherit lib; };
in
module
