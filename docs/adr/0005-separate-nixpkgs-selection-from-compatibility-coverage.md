---
status: accepted
---

# Separate nixpkgs selection from compatibility coverage

The root flake exposes one nixpkgs input, named `nixpkgs`, and its lock records the project's chosen development default. Consumers select their own revision with `follows` or native input overrides. Root `nix flake check` tests that selected revision; the shared policy owns selection and execution of the approved stable and unstable compatibility runs. Policy `v0.2.0` supports this separation, keeping compatibility pins outside the member's dependency graph and allowing an independent development default.

Flake-parts assembles development outputs through `perSystem`, with the supported systems and public output namespaces explicit in root `flake.nix`. A local module under `tests/` assembles checks and focused fixtures, keeping test construction out of the root flake. Shells, formatters, packages, all declared checks, focused fixtures, and NixOS examples use the selected input. Focused paths are `lib.tests.<system>.<fixture>` and `lib.failures.<system>.<fixture>`, and check names omit stable/unstable labels. Expected-failure fixtures remain lazy. The [changelog](../../CHANGELOG.md#migration) records the interface migration.

Compatibility uses the same root CLI with `--override-input nixpkgs` at an exact revision and `--no-write-lock-file`. The default run uses `--no-update-lock-file` to reject missing or stale lock selections. Each check evaluates applicable shell, formatter, package, and example outputs and builds every declared host check; it does not enter shells or build example systems. Existing offline fixture execution continues to bound evaluator memory.

The policy runner verifies the resolved input, nonempty host checks, and unchanged member sources and lock, then records the full check result and exact project, checker, policy-record, and dependency revisions. Both approved revisions are required on `x86_64-linux` and `aarch64-linux`. Required committed-default and development-tool checks remain separate. Pin approval, candidate rules, matrix execution, and reporting belong to the policy implementation; the member caller stays small and stores no copy of the compatibility pair.

The returned module keeps the receiver's `lib`, source attribution, and contribution behavior. `(import ./flake.nix).outputs { }` continues to expose `lib.mkModule`, `nixosModules.default`, and `flakeModules.default` without development inputs. The root returns these exports directly and selects development outputs by name from the flake-parts result. Merging the complete result into the public exports would force development inputs during plain imports. This intentional library interface has dedicated regression coverage; compatibility tests exercise the public flake CLI.

## Rejected alternative

The earlier decision used a separately locked compatibility flake that imported the parent flake and called its output function for each revision. [Issue #19](https://github.com/petohorvath/nixos-cross-config/issues/19) reopens that decision because the wrapper couples coverage to the repository layout, duplicates output aggregation, and reconstructs normal flake evaluation. Native overrides replace that wrapper and its second lockfile. Requiring the development default to equal the approved stable pin is also replaced by independent selection under policy `v0.2.0`.

## Policy activation

The caller uses `name: Policy`; the shared workflow derives ordinary and compatibility jobs from the central `requiredArchitectures` record. Activation requires matching member references and central `policyVersion`, successful stable and unstable runs on both recorded Linux architectures, and observed statuses matching the required merge gates. The [development instructions](../development.md#ci-and-policy) describe status derivation and record compatibility for the selected release. Preserve existing protections while preparing the transition and obtain human approval for activation and merges. Selecting the release or passing local checks alone does not complete that coordination.
