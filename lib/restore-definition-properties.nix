{ lib }:
option:
# Module evaluation strips these wrappers before exposing definitions.
map (definition: {
  inherit (definition) file;
  value = lib.mkOverride option.highestPrio (
    if definition ? priority then lib.mkOrder definition.priority definition.value else definition.value
  );
}) option.definitionsWithLocations
