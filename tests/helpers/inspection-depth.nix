# Counts the destination inspections that enclose a receiver evaluation, read
# from the private special argument that marks them.
let
  inspectionArgument = import ../../lib/inspection-argument.nix;
in
specialArgs: builtins.length (specialArgs.${inspectionArgument} or [ ])
