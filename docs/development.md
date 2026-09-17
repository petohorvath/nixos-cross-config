# Development

Use the root flake for development, formatting, and checks. The library's module factory still receives `lib` from the receiver and can be imported without resolving development inputs.

## Prerequisites

Install host Nix with `nix-command` and `flakes` enabled, Git, and direnv with flake support and shell integration. Flake support may come from direnv itself or nix-direnv. The shell's Nix executable becomes available after entry; host Nix is needed to enter it.

```bash
direnv allow
nix fmt --no-update-lock-file
nix flake check --no-update-lock-file --print-build-logs
```

`nix develop` is the explicit shell entrypoint. The default shell supports `x86_64-linux` and `aarch64-linux` and supplies Nix, nil, nixfmt, statix, deadnix, Git, shfmt, Prettier, actionlint, and the root formatter. All tools come from the stable `nixpkgs` input. No KVM access or VM execution is required.

## Formatting and lint

Root `nix fmt` uses the project-owned treefmt wrapper. Nix uses nixfmt; shell files and `.envrc` use shfmt; Markdown, YAML, and JSON use Prettier. Existing Markdown wrapping is preserved. New prose uses one source line per paragraph.

Formatting excludes Git metadata, direnv state, build results, and lockfiles.

Root `nix flake check` runs the same public fixtures against stable and unstable, their diagnostic and native-cycle checks, formatting, statix, deadnix, and workflow validation. Evaluation checks run fixtures in separate offline evaluator processes to bound memory; their JSON output preserves the focused result structure. The project has no VM targets.

[Root `flake.nix`](../flake.nix) declares the supported systems and public outputs. [The shell](../shell.nix) and [formatter](../formatter.nix) declare their package dependencies through `pkgs.callPackage`; [check assembly](../tests/checks.nix) lives beside the test runners. Plain Nix composition keeps development tooling separate from the library without a policy input or import.

## Focused checks

The [locked development inputs](../flake.lock), `nixpkgs` and `nixpkgs-unstable`, select NixOS 26.05 and unstable separately. The same public fixtures run once per revision; each collection uses only that revision.

```bash
# New files must be tracked before Git-backed flake evaluation.
git add <new-files>

# One fixture, including native NixOS option typechecking.
nix eval --json .#lib.tests.x86_64-linux.stable.merging
nix eval --json .#lib.tests.x86_64-linux.stable.priorities
nix eval --json .#lib.tests.x86_64-linux.stable.conditional
nix eval --json .#lib.tests.x86_64-linux.stable.senderContext
nix eval --json .#lib.tests.x86_64-linux.stable.selfTarget
nix eval --json .#lib.tests.x86_64-linux.stable.reciprocal
nix eval --json .#lib.tests.x86_64-linux.stable.destinations
nix eval --json .#lib.tests.x86_64-linux.stable.taggedDestinations

# Stable and unstable evaluation, diagnostics, cycles, formatting, and lint.
nix flake check --no-update-lock-file

# Format all applicable first-party files.
nix fmt --no-update-lock-file
```

Build individual check targets when investigating a failure:

```bash
nix build --no-link .#checks.x86_64-linux.stable
nix build --no-link .#checks.x86_64-linux.unstable
nix build --no-link .#checks.x86_64-linux.stable-value-cycle
nix build --no-link .#checks.x86_64-linux.unstable-value-cycle
nix build --no-link .#checks.x86_64-linux.stable-diagnostics
nix build --no-link .#checks.x86_64-linux.unstable-diagnostics
nix build --no-link .#checks.x86_64-linux.formatting
```

Fixtures force received values, host and guest assertions, and the example's system derivation paths. Priority and ordering fixtures cover whole options, nested values, multiple senders, receiver refinements, and transport selection. Expected failures force ordinary and explicit-priority conflicts, nested conflicts, invalid option types, and a contributed assertion through the receiver's system build. An individual failure can be inspected directly:

```bash
nix eval --json .#lib.failures.x86_64-linux.stable.localConflict
```

The [tagged-destination fixtures](../tests/tagged-destinations.nix) cover writable tags, receiver-local declarations and permissions, native type wrappers, priorities, laziness, and node relationships. Tagged diagnostics and native cycles run alongside the existing failure checks. The [destination inspection design](destination-inspection.md) explains how receiver-local option metadata is evaluated.

The [destination fixtures](../tests/destinations.nix) cover unused missing and read-only registrations on idle and active nodes, submodule paths, and disabled invalid contributions. [Failure fixtures](../tests/destination-failures.nix) force invalid destinations through receiver builds and unknown receivers and unregistered paths through sender builds. Separate [diagnostic checks](../tests/check-diagnostics.nix) verify failure reasons, contribution identities, destination paths, and source filenames on both pinned revisions.

```bash
nix eval --show-trace .#lib.failures.x86_64-linux.stable.missingDestination
nix eval --show-trace .#lib.failures.x86_64-linux.stable.unknownReceiver
```

The [conditional fixture](../tests/conditional.nix) exercises enabled and disabled branches at registered options and transport containers, including unevaluated disabled payloads. The [merging fixture](../tests/merging.nix) combines several exports targeting one receiver with another sender and local definitions. The [sender-context fixture](../tests/sender-context.nix) distinguishes captured sender values from receiving submodule arguments and refinements.

The [self-targeting](../tests/self-target.nix) and [reciprocal](../tests/reciprocal.nix) fixtures force received values on every participant. The [host and guest fixture](../tests/host-guest.nix) also covers guest-to-parent and guest-to-self contributions merged with local definitions. Separate evaluator checks require the [value-cycle fixture](../tests/value-cycle.nix) to fail with a native recursion error on both revisions. `tryEval` cannot catch that error. The failure can be inspected directly:

```bash
nix eval --json .#lib.failures.x86_64-linux.stable.valueCycle
# error: infinite recursion encountered
```

## CI and policy

The [CI caller](../.github/workflows/check.yml) invokes the shared policy workflow at an immutable revision. It checks the shell, formatting, lint, and ordinary project checks on both Linux architectures. Policy code stays outside this flake's inputs and build graph.

The policy repository's central project and pin records determine enrollment and pin approval. Passing readiness checks does not record either approval. Follow the shared [maintenance procedure](https://github.com/petohorvath/nixos-project-policy/blob/eecc24f9b1e87943d0266ef60c835a5ad35c78b7/docs/maintenance.md) for enrollment and dependency updates.
