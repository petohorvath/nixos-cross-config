---
status: accepted
---

# Separate nixpkgs selection from compatibility coverage

The root flake will expose one nixpkgs input, named `nixpkgs`, so consumers and individual invocations can select a revision without carrying a second test input in the root dependency graph. Root `nix flake check` will test the selected revision, while a separate reproducible local command and required CI coverage will test both approved stable and unstable revisions. This separates the revision selected for one flake evaluation from the project's compatibility commitment, at the cost of requiring the separate command to validate both revisions locally.

The flake will retain plain Nix composition; other tooling inputs remain possible when justified. Root test and failure outputs will omit the `stable` and `unstable` labels, with migration instructions for the existing paths.

A separate flake and lockfile under `tests/compatibility/` will commit the approved pair as `nixpkgs` and `nixpkgs-unstable`. That flake will instantiate the same checkout's root outputs with each revision and expose both sets of outputs for validation, without duplicating the test implementation or importing policy code. The local compatibility command will be `nix flake check ./tests/compatibility --no-update-lock-file`.

Compatibility validation will preserve ordinary `nix flake check` behavior for both root instances: evaluate the shell, formatter, package, and NixOS example outputs, and build every declared check for the host system. Each instance will use tools from its selected revision; the root's default lock will continue to select the approved stable revision for normal development. CI will cover both revisions on `x86_64-linux` and `aarch64-linux`, alongside the existing policy workflow, with the compatibility statuses included in the required merge checks.

The library contract will continue to use the receiver's `lib` and permit access to `lib.mkModule` through `(import ./flake.nix).outputs { }` without development inputs. The wrapper will need to account for any future additions to the root's checked output namespaces.
