---
status: accepted
---

# Separate nixpkgs selection from compatibility coverage

The root flake exposes one nixpkgs input, named `nixpkgs`, and its lock records the project's chosen development default. Consumers select their own revision with `follows` or native input overrides. Root `nix flake check` tests that selected revision; the shared policy owns selection and execution of the approved stable and unstable compatibility runs. Policy `v0.3.0` supports this separation, keeping compatibility pins outside the member's dependency graph and allowing an independent development default.

Root `flake.nix` returns `flake-parts.lib.mkFlake` directly. It declares the supported systems and the public `nixosModules.default`, `flakeModules.default`, and `lib` outputs. A `dev` partition assembles `checks`, `devShells`, and `formatter` through `perSystem`, keeping development wiring out of the root module. Shell, formatter, treefmt, and check assembly files live under `dev/`. The partition inherits the root inputs and introduces no additional flake or lockfile. The formatter is supplied to the default shell without a duplicate package output. `.envrc` remains at the root with `use flake`.

Check assembly passes the selected `nixpkgs` explicitly to the test runners. Suites, runners, and fixture helpers stay under `tests/`; examples stay under `examples/` and run through those suites instead of root `nixosConfigurations`. Public `lib` contains the constructor, while `dev/fixtures.nix` provides focused `tests` and lazy `failures` attributes. That helper accepts `nixpkgs` explicitly, defaulting to the root selection. Shells, formatters, checks, fixtures, and examples therefore share one selection per run. Check names omit stable/unstable labels. The [changelog](../../CHANGELOG.md#migration) records the interface migration.

Compatibility uses the same root CLI with `--override-input nixpkgs` at an exact revision and `--no-write-lock-file`. The default run uses `--no-update-lock-file` to reject missing or stale lock selections. Each run evaluates applicable shell and formatter outputs and builds every declared host check. Fixtures evaluate example systems without building them. Existing offline fixture execution continues to bound evaluator memory.

The policy runner verifies the resolved input, nonempty host checks, and unchanged member sources and lock, then records the full check result and exact project, checker, policy-record, and dependency revisions. Both approved revisions are required on `x86_64-linux` and `aarch64-linux`. Required committed-default and development-tool checks remain separate. Pin approval, candidate rules, matrix execution, and reporting belong to the policy implementation; the member caller stays small and stores no copy of the compatibility pair.

The returned module keeps the receiver's `lib`, source attribution, and contribution behavior. Plain Nix consumers import `nixos/module.nix`, `flake-module.nix`, or `(import ./lib).mkModule` without development inputs. The constructor lives in `lib/default.nix` and records that file as its default module location. Calling `(import ./flake.nix).outputs { }` is no longer supported, so the root needs no alternate evaluation path or shared export binding. Tests cover both the public flake exports assembled with supplied inputs and the direct imports; compatibility runs exercise the public flake CLI.

## Rejected alternative

The earlier decision used a separately locked compatibility flake that imported the parent flake and called its output function for each revision. [Issue #19](https://github.com/petohorvath/nixos-cross-config/issues/19) reopens that decision because the wrapper couples coverage to the repository layout, duplicates output aggregation, and reconstructs normal flake evaluation. Native overrides replace that wrapper and its second lockfile. Requiring the development default to equal the approved stable pin is also replaced by independent selection under policy `v0.2.0`.

## Policy activation

The caller uses `name: Policy`; the shared workflow derives ordinary and compatibility jobs from the central `requiredArchitectures` record. Activation requires matching member references and central `policyVersion`, successful stable and unstable runs on both recorded Linux architectures, and observed statuses matching the required merge gates. The [development instructions](../development.md#ci-and-policy) describe status derivation and record compatibility for the selected release. Preserve existing protections while preparing the transition and obtain human approval for activation and merges. Selecting the release or passing local checks alone does not complete that coordination.
