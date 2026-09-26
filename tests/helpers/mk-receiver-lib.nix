{ lib }:
name:
# Mark options declared through this lib so tests can tell whose lib built them.
lib
// {
  mkOption = arguments: lib.mkOption arguments // { receiverLibrary = name; };
}
