# Expected source locations, independent of the evaluated module metadata.
{
  mkModule = toString ../../lib/default.nix;
  module = toString ../../nixos/module.nix;
}
