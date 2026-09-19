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

Policy `v0.2.0` runs the same compatibility checker locally and in CI. It selects exact stable and unstable revisions from a trusted policy-record checkout, verifies the effective root input, requires nonempty host checks, and runs the full root `nix flake check`. It checks that the member sources and committed lock remain unchanged and writes metadata and result evidence outside the member checkout.

Use a trusted current record checkout at `../nixos-project-policy-records`. The project record must select `v0.2.0` and declare both Linux architectures; the project lock must match its committed copy. From the repository root, run each approved revision into a new evidence directory:

```bash
nix run --no-update-lock-file github:petohorvath/nixos-project-policy/v0.2.0 -- \
  --policy-root ../nixos-project-policy-records \
  compatibility . --project nixos-cross-config --channel stable \
  --output ../cross-config-stable-evidence
nix run --no-update-lock-file github:petohorvath/nixos-project-policy/v0.2.0 -- \
  --policy-root ../nixos-project-policy-records \
  compatibility . --project nixos-cross-config --channel unstable \
  --output ../cross-config-unstable-evidence
```

Keep the record snapshot fixed for both runs, then repeat on the other native Linux architecture. A local run covers its host architecture. The runner writes `result.json` for a completed attempt and `metadata.json` when metadata is available. Its evidence identifies selected and resolved revisions, commands, host check names, commits, and the record digest. Nix may reuse cached builds; a successful result does not mean every test process executed again. Static policy checks report `compatibility: "not-run"` and do not replace this evidence.

Ordinary compatibility runs use the approved pair. A candidate must be registered for the exact clean project commit; use the runner's `--batch ID` option to select an explicit candidate. Candidate success does not approve pins. The [runner reference](https://github.com/petohorvath/nixos-project-policy/blob/v0.2.0/docs/checker.md#compatibility-execution-and-evidence) defines selection and evidence, and [CI and policy](#ci-and-policy) describes coordinated activation.

The root lock records the development default independently of the compatibility pair. A shared-pin update requires new compatibility evidence without requiring a default-lock update. Compatibility selections remain outside member lockfiles and consumer dependency graphs. [ADR-0005](adr/0005-separate-nixpkgs-selection-from-compatibility-coverage.md) records this boundary.

For a focused investigation at another exact revision, set `NIXPKGS_REV` to its full commit and use a native override:

```bash
nix flake check --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --print-build-logs
```

The override deliberately changes the effective input graph without writing the lock. Use `--no-update-lock-file` alone, without an override or `--no-write-lock-file`, to validate the committed default. An arbitrary override is an investigation result, not a policy-approved compatibility result.

### Reproduce an exact result

Use the saved `result.json` to select the project `revision`, `checkerRevision`, and `policyRecordsRevision`, along with the reported architecture, expected nixpkgs revision, and any `candidateBatch`. Set `PROJECT_REV`, `CHECKER_REV`, and `POLICY_RECORD_REV` to those full commits. The checker checkout must be the clean release commit, and the records must be the reported snapshot rather than a later policy `main`.

From a scratch directory outside the member checkout, create separate checkouts:

```bash
git clone https://github.com/petohorvath/nixos-cross-config.git nixos-cross-config-repro
git -C nixos-cross-config-repro fetch origin "$PROJECT_REV"
git -C nixos-cross-config-repro checkout --detach "$PROJECT_REV"
git clone https://github.com/petohorvath/nixos-project-policy.git nixos-project-policy-checker
git -C nixos-project-policy-checker fetch origin "$CHECKER_REV"
git -C nixos-project-policy-checker checkout --detach "$CHECKER_REV"
git clone https://github.com/petohorvath/nixos-project-policy.git nixos-project-policy-records
git -C nixos-project-policy-records fetch origin "$POLICY_RECORD_REV"
git -C nixos-project-policy-records checkout --detach "$POLICY_RECORD_REV"
```

Validate the captured records and compare the reported `policyRecordsDigest` with the original evidence before replaying:

```bash
nix run --no-update-lock-file ./nixos-project-policy-checker -- \
  --policy-root ./nixos-project-policy-records validate
```

Run the same external checker on the reported native architecture, writing fresh evidence directories:

```bash
nix run --no-update-lock-file ./nixos-project-policy-checker -- \
  --policy-root ./nixos-project-policy-records \
  compatibility ./nixos-cross-config-repro --project nixos-cross-config \
  --channel stable --output ./replay-stable
nix run --no-update-lock-file ./nixos-project-policy-checker -- \
  --policy-root ./nixos-project-policy-records \
  compatibility ./nixos-cross-config-repro --project nixos-cross-config \
  --channel unstable --output ./replay-unstable
nix flake check ./nixos-cross-config-repro --no-update-lock-file --print-build-logs
```

Preserve the original candidate registration and add `--batch ID` when replaying an explicitly selected candidate. Compare each replay's record digest, source digests, system, and expected and resolved revisions with the saved evidence. Dirty local sources require their exact contents as well as the reported commit; candidates require a clean registered commit. Keep the record checkout fixed throughout replay.

The separate final command validates the committed default. Repeat compatibility execution on both required architectures to reproduce the full matrix. A focused fixture or cached check result must be reported with its actual scope; neither establishes a fresh execution of every test or changes enrollment and merge gates.

## Focused checks

The root [locked input](../flake.lock), `nixpkgs`, selects NixOS 26.05 by default. Focused paths omit stable/unstable labels and always use that selected input; each node collection uses only one revision.

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

The [CI workflow](../.github/workflows/check.yml) selects the published immutable policy release `v0.2.0` and names its caller job `Policy`. The shared workflow captures one release commit and one central-record commit, then derives ordinary and compatibility jobs from `requiredArchitectures`. This project's required coverage is `x86_64-linux` and `aarch64-linux`. Policy code stays outside the member's flake inputs and build graph.

Compliance, formatting/lint, committed-default project tests, and the two compatibility revisions run in independent jobs for each required architecture. The member caller supplies only `project` and `policy_version`; the policy owns pin selection and matrices. The project has no VM targets. Compatibility evidence is uploaded even when execution fails, and uploading evidence does not change the failed result.

Member references and current central records must select the same release before the checker can generate jobs. From the member root, use a trusted record checkout selecting `v0.2.0` to obtain the planned matrix and mandatory status names:

```bash
nix run --no-update-lock-file github:petohorvath/nixos-project-policy/v0.2.0 -- \
  --policy-root ../nixos-project-policy-records ci --project nixos-cross-config
```

The release defines the `Policy / ...` prefix and names, including `Compatibility (stable, <architecture>)` and `Compatibility (unstable, <architecture>)`. The `ci` result is a plan, not evidence that those jobs ran or that their gates are active. Follow the [v0.2.0 migration procedure](https://github.com/petohorvath/nixos-project-policy/blob/v0.2.0/docs/maintenance.md#migration-to-v020):

1. Coordinate policy links, the workflow reference, `policy_version`, central `policyVersion`, and both `requiredArchitectures`. Preserve the committed default and existing protections while preparing the transition.
2. Obtain a complete member CI run with successful ordinary and stable/unstable compatibility jobs on both architectures. Inspect the workflow implementation and actual emitted statuses on the reviewable PR.
3. Record the observed complete set in `requiredChecks`, then obtain separate authorization to update GitHub merge gates. Verify the resulting settings and obtain human approval for member activation and merge.

Selecting `v0.2.0` in this checkout does not update central records, record adoption, or change GitHub settings. Readiness and compatibility success also do not perform those actions. Current compliance checks use trusted current records from policy `main`; exact replay uses the captured snapshot instead. Compatibility-pair updates and development-default updates remain separate operations.
