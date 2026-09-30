{
  destinations,
  lib,
  nodeConfigurations,
  optionPaths,
  options,
  receiver,
}:
let
  # Reserved roots never receive paths, but defining them here would make
  # crossConfig and _module.args depend on optionPaths and recurse.
  receivingOptions = removeAttrs options (import ./reserved-roots.nix);

  withContributionContext =
    sender: path: definition:
    lib.mkDefinition {
      file =
        definition.file
        + " (sender `${sender}`, receiver `${receiver}`, destination `${lib.showOption path}`)";
      inherit (definition) value;
    };

  collectDefinitions =
    path:
    let
      collectSenderDefinitions =
        sender: node:
        map (withContributionContext sender path) (
          lib.attrByPath path [ ] (node.config.crossConfig.contributions.${receiver} or { })
        );
    in
    lib.pipe nodeConfigurations [
      (lib.mapAttrsToList collectSenderDefinitions)
      lib.concatLists
    ];

  mkReceivingNamespace =
    root: _:
    lib.pipe optionPaths [
      (builtins.filter (path: builtins.head path == root))
      (lib.concatMap (
        path:
        let
          # Resolve below the namespace so module arguments resolve.
          definition = destinations.receivingDefinition path (collectDefinitions path);
        in
        lib.optional (builtins.hasAttr root definition) definition.${root}
      ))
      lib.mkMerge
    ];

  mkDestinationAssertion =
    path:
    let
      definitions = collectDefinitions path;
      status = destinations.status path;
    in
    {
      assertion = definitions == [ ] || status == "writable";
      message =
        "nixos-cross-config: receiver `${receiver}` has a ${status} destination `${lib.showOption path}`.\nContributions: "
        + lib.concatMapStringsSep ", " (definition: definition.file) definitions
        + "\n";
    };
in
{
  receivedConfig = lib.mapAttrs mkReceivingNamespace receivingOptions;
  destinationAssertions = map mkDestinationAssertion optionPaths;
}
