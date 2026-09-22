{ lib }:
option:
let
  # Module evaluation strips override and ordering wrappers before exposing definitions.
  restoreDefinition = definition: {
    inherit (definition) file;
    value = lib.mkOverride option.highestPrio (restoreOrder definition);
  };

  restoreOrder =
    definition:
    if definition ? priority then
      lib.mkOrder definition.priority definition.value
    else
      definition.value;
in
map restoreDefinition option.definitionsWithLocations
