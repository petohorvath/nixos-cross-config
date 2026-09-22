# Development

Use the root flake for development, formatting, and checks. `nixosModules.default` and the `lib.mkModule` compatibility adapter receive `lib` from the receiver's NixOS evaluation. Both are available through plain Nix import without evaluating development inputs; see the [API reference](api.md#module-creation).

## Prerequisites

Install host Nix with `nix-command` and `flakes` enabled, Git, and direnv with flake support and shell integration. Flake support may come from direnv itself or nix-direnv. The shell's Nix executable becomes available after entry; host Nix is needed to enter it.

```bash
direnv allow
nix fmt --no-update-lock-file
nix flake check --no-update-lock-file --print-build-logs
```

`nix develop` is the explicit shell entrypoint. The default shell supports `x86_64-linux` and `aarch64-linux` and supplies Nix, nix-unit, nil, nixfmt, statix, deadnix, Git, shfmt, Prettier, actionlint, and the root formatter. All tools come from the selected `nixpkgs` input. Overriding that input also selects the shell and formatter tools. No KVM access or VM execution is required.

The root `.envrc` contains `use flake`. Development configuration lives in `dev/`, with one root `flake.nix` and `flake.lock`; `dev/` is a flake-parts partition, not a separate flake. `.prettierrc.json` stays at the root for editor discovery.

## Formatting and lint

Root `nix fmt` uses the project-owned treefmt wrapper. Nix uses nixfmt; shell files and `.envrc` use shfmt; Markdown, YAML, and JSON use Prettier. Existing Markdown wrapping is preserved. New prose uses one source line per paragraph.

Formatting excludes Git metadata, direnv state, build results, and lockfiles.

Root `nix flake check` runs `checks.<system>.tests` through nix-unit, alongside formatting, statix, deadnix, and workflow validation against the selected `nixpkgs` input. The test check includes value comparisons, expected errors, and diagnostic context from one collection. nix-unit returns a failing exit status for any unmet expectation. The Nix check builder invokes nix-unit separately for suite entries to bound evaluator memory, using store-path inputs and a temporary writable evaluation store inside the build sandbox. The writable store is needed because NixOS evaluation creates derivations and other store paths. The project has no VM targets.

The ordinary flake checker evaluates applicable shell and formatter outputs and builds every declared check for the host system. The test suites evaluate the examples, including their system derivation paths, without building example systems. The selected input supplies tools and configurations throughout that evaluation.

[Root `flake.nix`](../flake.nix) returns `mkFlake` directly, declaring the supported systems, `nixosModules.default`, `flakeModules.default`, and `lib`. Its `dev` partition supplies `checks`, `devShells`, and `formatter` through [dev/default.nix](../dev/default.nix). [The shell](../dev/shell.nix) and [formatter](../dev/formatter.nix) declare their package dependencies through `pkgs.callPackage`; [development composition](../dev/default.nix) supplies the selected inputs explicitly through [check assembly](../dev/checks.nix) to the nix-unit check. [Treefmt configuration](../dev/treefmt.toml) lives beside the formatter. The root library exports contain no focused fixtures or example nodes. Plain Nix consumers use `nixos/module.nix`, `flake-module.nix`, or `(import ./lib).mkModule`. The policy remains outside the input and import graph.

Behavior suites and their registry live in [tests/suites](../tests/suites/). The collection loader and check builder remain at the top of `tests/`. Shared node constructors and offline evaluation helpers live in [tests/helpers](../tests/helpers/). These helpers assemble the public flake exports with the supplied inputs, so the tests exercise the same exports consumers use. Concrete fixture modules and evaluated scenarios live in [tests/fixtures](../tests/fixtures/). Examples remain in `examples/` and run through the suites.

## Compatibility checks

Policy `v0.3.0` runs the same compatibility checker locally and in CI. It selects exact stable and unstable revisions from a trusted policy-record checkout, verifies the effective root input, requires nonempty host checks, and runs the full root `nix flake check`. It checks that the member sources and committed lock remain unchanged and writes metadata and result evidence outside the member checkout.

Use a trusted current record checkout at `../nixos-project-policy-records`. The project record must select `v0.3.0` and declare both Linux architectures; the project lock must match its committed copy. From the repository root, run each approved revision into a new evidence directory:

```bash
nix run --no-update-lock-file github:petohorvath/nixos-project-policy/v0.3.0 -- \
  --policy-root ../nixos-project-policy-records \
  compatibility . --project nixos-cross-config --channel stable \
  --output ../cross-config-stable-evidence
nix run --no-update-lock-file github:petohorvath/nixos-project-policy/v0.3.0 -- \
  --policy-root ../nixos-project-policy-records \
  compatibility . --project nixos-cross-config --channel unstable \
  --output ../cross-config-unstable-evidence
```

Keep the record snapshot fixed for both runs, then repeat on the other native Linux architecture. A local run covers its host architecture. The runner writes `result.json` for a completed attempt and `metadata.json` when metadata is available. Its evidence identifies selected and resolved revisions, commands, host check names, commits, and the record digest. Nix may reuse cached builds; a successful result does not mean every test process executed again. Static policy checks report `compatibility: "not-run"` and do not replace this evidence.

Ordinary compatibility runs use the approved pair. A candidate must be registered for the exact clean project commit; use the runner's `--batch ID` option to select an explicit candidate. Candidate success does not approve pins. The [runner reference](https://github.com/petohorvath/nixos-project-policy/blob/v0.3.0/docs/checker.md#compatibility-execution-and-evidence) defines selection and evidence, and [CI and policy](#ci-and-policy) describes coordinated activation.

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

Root `nix flake check --no-update-lock-file --print-build-logs` runs the complete test collection through `checks.<system>.tests`, alongside formatting and lint. For a focused run, use nix-unit from the default development shell at the repository root:

```bash
nix-unit tests/entrypoint.nix --attr merging
nix-unit tests/entrypoint.nix --attr destinations.testRejectsMissingDestination
nix-unit tests/entrypoint.nix --attr destinations.testRejectsUnregisteredDestination
```

A suite name selects its descendants; a full test name selects one case. Every selected case includes its value or error expectations, including required message fragments. nix-unit handles discovery, selection, comparisons, error matching, and reporting. It reads the current checkout, so edits to tests are available without re-entering the shell. Track new files with `git add` before Git-backed flake evaluation.

[tests/entrypoint.nix](../tests/entrypoint.nix) loads the complete collection with the root locked inputs by default. The root [locked input](../flake.lock), `nixpkgs`, selects NixOS 26.05. The loader returns test definitions from `tests/suites/default.nix`; evaluating it alone does not verify expectations. `tests/checks.nix` wraps nix-unit in a Nix build, and `dev/checks.nix` registers that build as the root test check. Raw configurations under [tests/fixtures](../tests/fixtures/) are private inputs to the suites.

For a focused investigation at another exact revision, set `NIXPKGS_REV` to its full commit and select it for both the development tools and the test loader:

```bash
nix develop --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --command \
  nix-unit tests/entrypoint.nix --attr merging \
  --arg nixpkgs "(builtins.getFlake \"github:NixOS/nixpkgs/$NIXPKGS_REV\")"
```

The shell override selects the tools; the explicit argument selects the tested configurations and the nixpkgs library used by flake-parts. Neither command writes the lock. A focused run does not replace the full root check or policy compatibility execution.

### Test definitions

[tests/suites/default.nix](../tests/suites/default.nix) registers suites by behavior. Each test name starts with `test` and pairs `expr` with `expected`, or with native nix-unit `expectedError` for a rejection case. Declare the expected error type and message pattern beside the expression. The private [message-pattern helper](../tests/helpers/message-pattern.nix) builds a regex requiring every supplied literal fragment, in any order and across line breaks:

```nix
testRejectsMissingDestination = {
  expr = rejections.missingDestination;
  expectedError = {
    type = "ThrownError";
    msg = messagePattern [
      "missing destination"
      "sender `sender`"
      "receiver `receiver`"
      "fixtures/destination-sender.nix"
    ];
  };
};
```

All expectations use nix-unit's standard definition shape. Error tests match the underlying error message. The unregistered-destination case checks its rejection reason, option path, and original source file; additional sender wording in the evaluator stack trace is outside that expectation. A mismatch prints the test name and the relevant value difference or error mismatch, and causes the command to fail. Use nix-unit's `--show-trace` option when investigating unexpected evaluation errors.

The ordinary node helpers exercise `nixosModules.default` through the public flake export. [Module](../tests/suites/module.nix) and [setting](../tests/suites/module-settings.nix) suites cover receiver-supplied `lib`, reciprocal contributions, shared registrations, normalization, priorities, required settings, and lazy collections. [Constructor tests](../tests/suites/mk-module.nix) cover `lib.mkModule`; `plainImports` repeats the module and constructor suites through direct imports without development inputs.

[Flake-module tests](../tests/suites/flake-module.nix) assemble consumers with flake-parts through the public export and cover default and explicit collections, shared settings, node defaults, plain imports, and invalid settings. The selected flake-parts library follows the same nixpkgs revision as the evaluated nodes. The example suites evaluate system derivation paths without building example systems.

[Destination](../tests/suites/destinations.nix) and [tagged-destination](../tests/suites/tagged-destinations.nix) suites pair accepted configurations with rejection cases for missing, read-only, incompatible, and conflicting destinations. Their error expectations verify contribution identities, destination paths, and source filenames. [Merging](../tests/suites/merging.nix), [priorities](../tests/suites/priorities.nix), [nested properties](../tests/suites/nested-properties.nix), and [forwarding](../tests/suites/forwarding.nix) include conflict, type, and contributed-assertion rejection cases beside successful behavior. [Reciprocal](../tests/suites/reciprocal.nix) and tagged-destination tests require native recursion errors only for actual value-dependency cycles. The [destination inspection design](destination-inspection.md) explains the receiver-local metadata evaluation.

## CI and policy

The [CI workflow](../.github/workflows/check.yml) selects the published immutable policy release `v0.3.0` and names its caller job `Policy`. The shared workflow captures one release commit and one central-record commit, then derives ordinary and compatibility jobs from `requiredArchitectures`. This project's required coverage is `x86_64-linux` and `aarch64-linux`. Policy code stays outside the member's flake inputs and build graph.

Compliance, formatting/lint, committed-default project tests, and the two compatibility revisions run in independent jobs for each required architecture. The member caller supplies only `project` and `policy_version`; the policy owns pin selection and matrices. The project has no VM targets. Compatibility evidence is uploaded even when execution fails, and uploading evidence does not change the failed result.

Member references and current central records must select the same release before the checker can generate jobs. From the member root, use a trusted record checkout selecting `v0.3.0` to obtain the planned matrix and mandatory status names:

```bash
nix run --no-update-lock-file github:petohorvath/nixos-project-policy/v0.3.0 -- \
  --policy-root ../nixos-project-policy-records ci --project nixos-cross-config
```

The release derives mandatory `Policy / ...` statuses from `requiredArchitectures` and `vmTargets`, including `Compatibility (stable, <architecture>)` and `Compatibility (unstable, <architecture>)`. Project-specific gates belong in `additionalRequiredChecks`; this project has none. The `ci` result includes the complete required set and its matrices, but does not establish that jobs ran or gates are active. The mandatory names are unchanged from v0.2.0. Follow the [v0.3.0 migration procedure](https://github.com/petohorvath/nixos-project-policy/blob/v0.3.0/docs/maintenance.md#migration-to-v030):

1. Coordinate policy links, the workflow reference, `policy_version`, central `policyVersion`, and both `requiredArchitectures`. Preserve the committed default and existing protections while preparing the transition.
2. Obtain a complete member CI run with successful ordinary and stable/unstable compatibility jobs on both architectures. Inspect the workflow implementation and actual emitted statuses on the reviewable PR.
3. Compare the generated complete set with observed PR statuses and GitHub merge gates. Move any project-specific gates to `additionalRequiredChecks`. Obtain separate authorization for any necessary GitHub merge-setting changes and preserve the verification evidence on the migration PR.
4. While any member still selects a release before v0.3.0, including a pending member, retain the complete generated set in this adopted member's `requiredChecks` for older checkers. The list must exactly match the generated set. Remove that duplicate only after the last older selection is migrated or removed through a separately selected record change. Obtain human approval for activation and merge.

Selecting `v0.3.0` in this checkout does not update central records, record adoption, or change GitHub settings. Readiness and compatibility success also do not perform those actions. Current compliance checks use trusted current records from policy `main`; exact replay uses the captured snapshot instead. Compatibility-pair updates and development-default updates remain separate operations.
