{
  lib,
  nodeName ? null,
}:
let
  settings = {
    inherit reservedRoots;
    options = {
      nodeCollection = lib.mkOption {
        type = lib.types.mkOptionType {
          name = "nodeCollection";
          description = "an attribute set of evaluated nodes";
          check = builtins.isAttrs;
          # Report only source locations: rendering conflicting values can force nodes.
          merge =
            location: definitions:
            if builtins.length definitions == 1 then
              (builtins.head definitions).value
            else
              throw (
                "The option `${lib.showOption location}' is defined multiple times. "
                + "Supply one node collection using option priorities. Definitions: "
                + lib.concatMapStringsSep ", " (definition: definition.file) definitions
              );
        };
        description = "Required opaque collection of caller-owned nodes exposing .config. All participants must share this collection.";
      };
      optionPaths = lib.mkOption {
        type = (lib.types.listOf (lib.types.nonEmptyListOf lib.types.str)) // {
          # An explicit empty list is valid, but an unset registration list is not.
          emptyValue = { };
        };
        apply = paths: lib.unique (map validatePath paths);
        description = "Required shared list of allowed destination paths, each a nonempty list of literal string segments. An empty outer list permits no contributions.";
      };
    };
  };
  reservedRoots = [
    "crossConfig"
    "_module"
  ];
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
in
settings
