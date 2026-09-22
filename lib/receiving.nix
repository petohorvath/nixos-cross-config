{
  extendModules,
  inspectionPaths,
  lib,
  name,
  nodes,
  optionPaths,
  options,
}:
let
  receiving = {
    inherit mkReceivingNamespace;
    assertions = map mkDestinationAssertion optionPaths;
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
      definitions = lib.mkMerge (collectDefinitions path);
      option = findReceivingOption path;

      mergeAtOption =
        remaining:
        if remaining == [ ] then
          definitions
        else
          # Inspect instances only inside their declared writable option.
          lib.mkMerge (lib.optional (isWritable option) (lib.setAttrByPath remaining definitions));

      buildPath =
        remaining: declarations:
        if remaining == [ ] then
          { }
        else
          let
            segment = builtins.head remaining;
            rest = builtins.tail remaining;
            destination = declarations.${segment} or null;
          in
          lib.optionalAttrs (destination != null && (!lib.isOption destination || isWritable destination)) {
            ${segment} = if lib.isOption destination then mergeAtOption rest else buildPath rest destination;
          };
    in
    # Keep declaration inspection below its namespace so module arguments resolve.
    buildPath path options;

  mkDestinationAssertion =
    path:
    let
      option = findReceivingOption path;
      definitions = collectDefinitions path;
      reason = if option == null then "missing" else "read-only";
    in
    {
      assertion = definitions == [ ] || isWritable option;
      message = ''
        nixos-cross-config: receiver `${name}` has a ${reason} destination `${lib.showOption path}`.
        Contributions: ${lib.concatMapStringsSep ", " (definition: definition.file) definitions}
      '';
    };

  findReceivingOption = import ./destination-inspection.nix {
    inherit
      extendModules
      inspectionPaths
      lib
      options
      ;
  };

  collectDefinitions =
    path:
    let
      fromSender =
        sender: node:
        map (withContributionContext sender path) (
          lib.attrByPath path [ ] (node.config.crossConfig.nodes.${name} or { })
        );
    in
    lib.pipe nodes [
      (lib.mapAttrsToList fromSender)
      lib.concatLists
    ];

  withContributionContext =
    sender: path: definition:
    lib.mkDefinition {
      file =
        definition.file
        + " (sender `${sender}`, receiver `${name}`,"
        + " destination `${lib.showOption path}`)";
      inherit (definition) value;
    };

  isWritable = option: option != null && !(option.readOnly or false);
in
receiving
