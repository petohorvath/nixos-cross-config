{ lib }:
lib.mkOption {
  type = lib.types.str;
  default = 42;
  description = "An invalid tag default with an explicit declaration origin.";
}
// {
  declarations = [ (toString ./tagged-default.nix) ];
}
