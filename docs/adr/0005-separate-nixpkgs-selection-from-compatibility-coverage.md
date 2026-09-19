---
status: accepted
---

# Separate nixpkgs selection from compatibility coverage

The root flake exposes one nixpkgs input, named `nixpkgs`, and its lock records the project's chosen development default. Consumers select their own revision with `follows` or native input overrides. Root `nix flake check` tests that selected revision; the shared policy owns selection and execution of the approved stable and unstable compatibility runs. This keeps compatibility pins outside the member's dependency graph and lets the development default change independently once the supporting policy is active.

Plain Nix composition and explicit root output namespaces remain. Shells, formatters, packages, all declared checks, focused fixtures, and NixOS examples use the selected input. Focused paths are `lib.tests.<system>.<fixture>` and `lib.failures.<system>.<fixture>`, and check names omit channel labels. Expected-failure fixtures remain lazy. The [changelog](../../CHANGELOG.md#migration) records the interface migration.

Compatibility uses the same root CLI with `--override-input nixpkgs` at an exact revision and `--no-write-lock-file`. The default run uses `--no-update-lock-file` to reject missing or stale lock selections. Each check evaluates applicable shell, formatter, package, and example outputs and builds every declared host check; it does not enter shells or build example systems. Existing offline fixture execution continues to bound evaluator memory.

The policy runner must verify the resolved input and unchanged member lock, execute both approved revisions on `x86_64-linux` and `aarch64-linux`, and report the exact project, policy-release, policy-record, and dependency revisions. Required committed-default and development-tool checks remain separate. Pin approval, candidate rules, matrix execution, and reporting belong to the policy implementation; the member caller stays small and stores no copy of the compatibility pair.

The returned module keeps the receiver's `lib`, source attribution, and contribution behavior. `(import ./flake.nix).outputs { }` continues to expose `lib.mkModule` without development inputs. This intentional library interface has dedicated regression coverage; compatibility tests exercise the public flake CLI.

## Rejected alternative

The earlier decision used a separately locked compatibility flake that imported the parent flake and called its output function for each revision. [Issue #19](https://github.com/petohorvath/nixos-cross-config/issues/19) reopens that decision because the wrapper couples coverage to the repository layout, duplicates output aggregation, and reconstructs normal flake evaluation. Native overrides replace that wrapper and its second lockfile. Requiring the development default to equal the approved stable pin is also replaced by independent selection under the supporting policy.

## Policy activation

The selected policy release `v0.1.1` requires approved revisions in member locks and stable development tools; it cannot activate this design's independent default or compatibility matrix. Activation requires a published immutable policy release implementing verified overrides, both channels on both Linux architectures, and reproducible reports. Member policy links, workflow references, and the central project record must select that release together. Inspect actual successful job names before adding matching required statuses, preserve existing merge protections, and obtain human approval. Until that transition, the retained default remains subject to `v0.1.1` and its default checks do not establish the new compatibility commitment.
