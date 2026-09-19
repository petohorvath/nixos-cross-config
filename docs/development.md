# Development

Use the root flake for development, formatting, and checks. The module returned by `lib.mkModule` receives `lib` from the receiver's NixOS evaluation. The function is also available through a plain Nix import without evaluating development inputs; see the [API reference](api.md#module-creation).

## Prerequisites

Install host Nix with `nix-command` and `flakes` enabled, Git, and direnv with flake support and shell integration. Flake support may come from direnv itself or nix-direnv. The shell's Nix executable becomes available after entry; host Nix is needed to enter it.

```bash
direnv allow
nix fmt --no-update-lock-file
nix flake check --no-update-lock-file --print-build-logs
```

`nix develop` is the explicit shell entrypoint. The default shell supports `x86_64-linux` and `aarch64-linux` and supplies Nix, nil, nixfmt, statix, deadnix, Git, shfmt, Prettier, actionlint, and the root formatter. All tools come from the selected `nixpkgs` input. Overriding that input also selects the shell and formatter tools. No KVM access or VM execution is required.

## Formatting and lint

Root `nix fmt` uses the project-owned treefmt wrapper. Nix uses nixfmt; shell files and `.envrc` use shfmt; Markdown, YAML, and JSON use Prettier. Existing Markdown wrapping is preserved. New prose uses one source line per paragraph.

Formatting excludes Git metadata, direnv state, build results, and lockfiles.

Root `nix flake check` runs the public fixtures, diagnostic and native-cycle checks, formatting, statix, deadnix, and workflow validation against the selected `nixpkgs` input. Evaluation checks run fixtures in separate offline evaluator processes to bound memory; their JSON output preserves the focused result structure. The project has no VM targets.

The ordinary flake checker evaluates applicable shells, formatters, packages, and NixOS examples and builds every declared check for the host system. Evaluating those outputs does not enter shells or build example systems. The selected input supplies tools and configurations throughout that evaluation.

[Root `flake.nix`](../flake.nix) declares the supported systems and public outputs. [The shell](../shell.nix) and [formatter](../formatter.nix) declare their package dependencies through `pkgs.callPackage`; [check assembly](../tests/checks.nix) lives beside the test runners. Plain Nix composition keeps development tooling separate from the library without a policy input or import.

## Compatibility checks

The root lock records the development default. Another exact revision can be selected for one invocation through Nix's native input override. Set `NIXPKGS_REV` to the full nixpkgs commit under investigation and run from the repository root:

```bash
nix flake check --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --print-build-logs
```

`--no-write-lock-file` permits the intentional in-memory selection while preserving the committed lock. Do not add `--no-update-lock-file` to an override command: that flag rejects the selection change. Keep `--no-update-lock-file` for the ordinary committed-default check.

Compatibility requires full root runs at both approved stable and unstable commits from one trusted policy-record snapshot, on both supported Linux architectures. Repeat the command for each exact commit. A local run covers its host architecture. Arbitrary revisions may be selected for investigation, but they are not policy-approved compatibility results. The [CI and policy](#ci-and-policy) requirements below govern activation of that required matrix.

The compatibility selections are external to the member lock and consumer dependency graph. Under the supporting policy, an approved-pair update does not require a development-default update. The current default remains unchanged, and changing it independently requires the policy transition described below. [ADR-0005](adr/0005-separate-nixpkgs-selection-from-compatibility-coverage.md) records this boundary.

### Reproduce an exact result

Use the exact tested project commit, policy release and its resolved commit, central policy-record commit, architecture, and nixpkgs revision reported by CI. For a locally prepared run, record those same selections. Select the approved pair from `policy/pins.json` at that record commit, and check the project's `policyVersion` in `policy/projects.json`. A later update of policy `main` must not change a reproduction. Candidate runs must use the candidate identified by the report and the selected policy release's candidate rules.

Set `PROJECT_REV` and `POLICY_RECORD_REV` to those full commits, then create separate checkouts:

```bash
git clone https://github.com/petohorvath/nixos-cross-config.git nixos-cross-config-repro
git -C nixos-cross-config-repro fetch origin "$PROJECT_REV"
git -C nixos-cross-config-repro checkout --detach "$PROJECT_REV"
git clone https://github.com/petohorvath/nixos-project-policy.git nixos-project-policy-records
git -C nixos-project-policy-records fetch origin "$POLICY_RECORD_REV"
git -C nixos-project-policy-records checkout --detach "$POLICY_RECORD_REV"
git -C nixos-project-policy-records show "$POLICY_RECORD_REV:policy/pins.json"
git -C nixos-project-policy-records show "$POLICY_RECORD_REV:policy/projects.json"
cd nixos-cross-config-repro
```

Set `NIXPKGS_REV` to the reported stable or unstable commit and verify its selection before running the full check:

```bash
nix flake metadata --json \
  --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file

LOCK_HASH_BEFORE=$(git hash-object flake.lock)
nix flake check --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --print-build-logs
test "$LOCK_HASH_BEFORE" = "$(git hash-object flake.lock)"
git diff --exit-code -- flake.lock
```

In the metadata JSON, resolve the root's `nixpkgs` input under `locks` and confirm its locked `rev` equals `NIXPKGS_REV`. Run on the reported architecture and repeat for the other approved revision when validating the pair. A successful focused fixture does not replace a full check run.

After policy activation, reproduce policy validation with the selected release's documented external runner, selecting this exact project checkout and policy-record checkout. That runner must verify approval, input resolution, and unchanged locks and report its selections. The published `v0.1.1` checker has no compatibility runner, so native commands currently provide local execution without establishing the new policy matrix.

## Focused checks

The root [locked input](../flake.lock), `nixpkgs`, selects NixOS 26.05 by default. Focused paths have no channel component and always use that selected input; each node collection uses only one revision.

```bash
# New files must be tracked before Git-backed flake evaluation.
git add <new-files>

# One fixture, including native NixOS option typechecking.
nix eval --json .#lib.tests.x86_64-linux.merging
nix eval --json .#lib.tests.x86_64-linux.priorities
nix eval --json .#lib.tests.x86_64-linux.conditional
nix eval --json .#lib.tests.x86_64-linux.senderContext
nix eval --json .#lib.tests.x86_64-linux.selfTarget
nix eval --json .#lib.tests.x86_64-linux.reciprocal
nix eval --json .#lib.tests.x86_64-linux.destinations
nix eval --json .#lib.tests.x86_64-linux.taggedDestinations

# Evaluation, diagnostics, cycles, formatting, and lint for the selected input.
nix flake check --no-update-lock-file

# Format all applicable first-party files.
nix fmt --no-update-lock-file
```

Build individual check targets when investigating a failure:

```bash
nix build --no-link .#checks.x86_64-linux.evaluation
nix build --no-link .#checks.x86_64-linux.value-cycle
nix build --no-link .#checks.x86_64-linux.diagnostics
nix build --no-link .#checks.x86_64-linux.formatting
```

For an individual fixture or check at another exact revision, use the same selection as the compatibility command:

```bash
nix eval --json --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file .#lib.tests.x86_64-linux.merging
nix build --no-link --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file .#checks.x86_64-linux.diagnostics
```

Fixtures evaluate received values, host and guest assertions, and the example's system derivation paths. Priority and ordering fixtures cover whole options, nested values, multiple senders, local option definitions, and selection of outgoing contributions. Expected failures check ordinary and explicit-priority conflicts, nested conflicts, invalid option types, and a contributed assertion through the receiver's system build. An individual failure can be inspected directly:

```bash
nix eval --json .#lib.failures.x86_64-linux.localConflict
```

The [tagged-destination fixtures](../tests/tagged-destinations.nix) cover writable tags, receiver-local declarations and permissions, native type wrappers, priorities, laziness, and node relationships. Tagged diagnostics and native cycles run alongside the existing failure checks. The [destination inspection design](destination-inspection.md) explains how receiver-local option metadata is evaluated.

The [destination fixtures](../tests/destinations.nix) cover unused missing and read-only registrations on idle and active nodes, submodule paths, and disabled invalid contributions. [Failure fixtures](../tests/destination-failures.nix) force invalid destinations through receiver builds and unknown receivers and unregistered paths through sender builds. Separate [diagnostic checks](../tests/check-diagnostics.nix) verify failure reasons, contribution identities, destination paths, and source filenames under the selected revision. Expected-failure fixtures stay lazy and fail only when deliberately forced by focused evaluation or the diagnostic runner.

```bash
nix eval --show-trace .#lib.failures.x86_64-linux.missingDestination
nix eval --show-trace .#lib.failures.x86_64-linux.unknownReceiver
```

The [conditional fixture](../tests/conditional.nix) exercises enabled and disabled branches at allowed option paths, `crossConfig.nodes`, and receiver entries, including unevaluated disabled payloads. The [merging fixture](../tests/merging.nix) combines several contributions from one sender with another sender's contributions and local definitions. The [sender-context fixture](../tests/sender-context.nix) distinguishes sender values from receiving submodule arguments and local option definitions.

The [self-targeting](../tests/self-target.nix) and [reciprocal](../tests/reciprocal.nix) fixtures force received values on every participant. The [host and guest fixture](../tests/host-guest.nix) also covers guest-to-parent and guest-to-self contributions merged with local definitions. Separate evaluator checks require the [value-cycle fixture](../tests/value-cycle.nix) to fail with a native recursion error under the selected revision. `tryEval` cannot catch that error. The failure can be inspected directly:

```bash
nix eval --json .#lib.failures.x86_64-linux.valueCycle
# error: infinite recursion encountered
```

## CI and policy

The [CI workflow](../.github/workflows/check.yml) selects the published immutable policy release `v0.1.1`. Its workflow checks the committed default, development shell, formatting, and lint on both Linux architectures. It does not override the selected input to run both compatibility revisions. Policy code stays outside the flake inputs and build graph.

Policy `v0.1.1` requires approved revisions in member locks and stable development tools. Independent development defaults and policy-owned compatibility require a new immutable policy release that supplies verified native overrides, both channels on both Linux architectures, candidate rules, and reproducible reports. No supporting release is selected. The member must not replace the missing shared implementation with local pin copies or label arbitrary overrides as approved results.

Activate the new policy in this order:

1. Select a published immutable release implementing the required compatibility runner and independent-default rules.
2. Coordinate the member's policy links, reusable-workflow reference, `policy_version`, and central project `policyVersion`. Retain the committed-default and development-tool checks.
3. Obtain successful stable and unstable compatibility results on both Linux architectures and inspect the workflow implementation and actual emitted status names.
4. Record those statuses in central `requiredChecks` and GitHub's merge gates while preserving existing protections. Require human approval before merging the migration.

The policy release supplies the rules and checker code. Current project and pin records on policy `main` determine enrollment and approved revisions; each CI run captures one record commit. Under the new policy, compatibility-pair updates and development-default updates are separate operations. Passing local checks or existing `v0.1.1` jobs does not establish the new matrix, central enrollment, or matching merge gates. Follow the selected release's maintenance procedure for activation; the current [v0.1.1 procedure](https://github.com/petohorvath/nixos-project-policy/blob/v0.1.1/docs/maintenance.md) governs the existing enrollment.
