# Compatibility constructor for the option-configured NixOS module.
{
  name,
  nodes,
  optionPaths,
}:
{
  imports = [ ./module.nix ];
  crossConfig = {
    inherit name optionPaths;
    nodeCollection = nodes;
  };
}
