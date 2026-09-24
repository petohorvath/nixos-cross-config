{ lib }:
lib.mkOption {
  type = lib.types.submodule (
    { config, ... }: {
      options = {
        locked = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Receiver-local write restriction.
          '';
        };
        value = lib.mkOption {
          type = lib.types.str;
          default = "local";
          readOnly = config.locked;
          description = ''
            A field protected by the receiver's local configuration.
          '';
        };
      };
    }
  );
  description = ''
    A tag with receiver-local child permissions.
  '';
}
