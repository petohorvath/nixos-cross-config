/*
  Declares the settings shared by every node in a collection, so both the
  NixOS module and the flake module can offer them. Per-node options such as
  crossConfig.name stay in nixos/module.nix; a flake-level default for them
  would give every node the same identity.
*/
{
  lib,
  nodeName ? null,
}:
let
  reservedRoots = import ./reserved-roots.nix;

  mergeNodeConfigurations =
    location: definitions:
    if builtins.length definitions == 1 then
      (builtins.head definitions).value
    else
      # Report only source locations: rendering conflicting values can force
      # nodes.
      throw (
        "The option `${lib.showOption location}' is defined multiple times. Supply one node collection using option priorities. Definitions: "
        + lib.concatMapStringsSep ", " (definition: definition.file) definitions
      );

  nodeConfigurationsType = lib.types.mkOptionType {
    name = "nodeConfigurations";
    description = "an attribute set of evaluated nodes";
    check = builtins.isAttrs;
    merge = mergeNodeConfigurations;
  };

  optionPathType = lib.types.nonEmptyListOf lib.types.str;

  optionPathsType = lib.types.listOf optionPathType // {
    # An explicit empty list is valid, but an unset registration list is not.
    emptyValue = { };
  };

  validatePath =
    path:
    if builtins.elem (builtins.head path) reservedRoots then
      throw (
        "nixos-cross-config: crossConfig.optionPaths registration `${lib.showOption path}`"
        + lib.optionalString (nodeName != null) " on node `${nodeName}`"
        + " uses a reserved root."
      )
    else
      path;

  # A sender cannot declare an option inside another option, and keeping only
  # the outer path would fail where it names a namespace on a receiver.
  rejectOverlaps =
    paths:
    let
      overlaps = lib.concatMap (
        outer:
        map (inner: { inherit inner outer; }) (
          builtins.filter (path: path != outer && lib.lists.hasPrefix outer path) paths
        )
      ) paths;
      overlap = builtins.head overlaps;
    in
    if overlaps == [ ] then
      paths
    else
      throw (
        "nixos-cross-config: crossConfig.optionPaths registrations `${lib.showOption overlap.outer}` and `${lib.showOption overlap.inner}`"
        + lib.optionalString (nodeName != null) " on node `${nodeName}`"
        + " overlap. Register only one of them."
      );

  normalizePaths =
    paths:
    lib.pipe paths [
      (map validatePath)
      lib.unique
      rejectOverlaps
    ];
in
{
  options = {
    nodeConfigurations = lib.mkOption {
      type = nodeConfigurationsType;
      description = ''
        Required opaque collection of caller-owned nodes exposing .config. All
        participants must share this collection.
      '';
    };

    optionPaths = lib.mkOption {
      type = optionPathsType;
      apply = normalizePaths;
      description = ''
        Required shared list of allowed destination paths, each a nonempty list
        of literal string segments. An empty outer list permits no
        contributions.
      '';
    };
  };
}
