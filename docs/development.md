# Development

Use the root flake for development, formatting, and checks. `nixosModules.default` and the `lib.mkModule` compatibility adapter receive `lib` from the receiver's NixOS evaluation. Both are available through plain Nix import without evaluating development inputs; see the [API reference](api.md#module-creation).

## Prerequisites

Install host Nix with `nix-command` and `flakes` enabled, Git, and direnv with shell integration. The root `.envrc` uses nix-direnv for flake support, reusing an installed version of at least 3.2.0 or downloading the checksum-verified 3.2.0 release on first activation. This download requires network access. The shell's Nix executable becomes available after entry; host Nix is needed to enter it.

```bash
direnv allow
nix fmt --no-update-lock-file
nix flake check --no-update-lock-file --print-build-logs
```

`nix develop` is the explicit shell entrypoint. The default shell supports `x86_64-linux` and `aarch64-linux` and supplies Nix, nix-unit, nil, nixfmt, statix, deadnix, Git, shfmt, Prettier, actionlint, and the root formatter. All tools come from the selected `nixpkgs` input. Overriding that input also selects the shell and formatter tools. No KVM access or VM execution is required.

The root `.envrc` loads nix-direnv before calling `use flake`. nix-direnv caches the development environment and protects its dependencies from Nix garbage collection. Development configuration lives in `dev/`, with one root `flake.nix` and `flake.lock`; `dev/` is a flake-parts partition, not a separate flake. `.prettierrc.json` stays at the root for editor discovery.

## Formatting and lint

Root `nix fmt` uses the project-owned treefmt wrapper. Nix uses nixfmt; shell files and `.envrc` use shfmt; Markdown, YAML, and JSON use Prettier. Existing Markdown wrapping is preserved. New prose uses one source line per paragraph.

Formatting excludes Git metadata, direnv state, build results, and lockfiles.

Root `nix flake check` runs `checks.<system>.tests` through nix-unit, alongside formatting, statix, deadnix, and workflow validation against the selected `nixpkgs` input. The test check includes value comparisons, expected errors, and diagnostic context from one collection. nix-unit returns a failing exit status for any unmet expectation. The Nix check builder invokes nix-unit separately for suite entries to bound evaluator memory, using store-path inputs and a temporary writable evaluation store inside the build sandbox. The writable store is needed because NixOS evaluation creates derivations and other store paths. The project has no VM targets.

The ordinary flake checker evaluates applicable shell and formatter outputs and builds every declared check for the host system. The test suites evaluate the examples, including their system derivation paths, without building example systems. The selected input supplies tools and configurations throughout that evaluation.

[Root `flake.nix`](../flake.nix) returns `mkFlake` directly, declaring the supported systems, `nixosModules.default`, `flakeModules.default`, and `lib`. Its `dev` partition supplies `checks`, `devShells`, and `formatter` through [dev/default.nix](../dev/default.nix). [The shell](../dev/shell.nix) and [formatter](../dev/formatter.nix) declare their package dependencies through `pkgs.callPackage`; [development composition](../dev/default.nix) supplies the selected inputs explicitly through [development check wiring](../dev/checks.nix) to the [check assembler](../tests/default.nix). The assembler owns the test, formatting, and lint checks. [Treefmt configuration](../dev/treefmt.toml) lives beside the formatter. The root library exports contain no focused fixtures or example nodes. Plain Nix consumers use `nixos/module.nix`, `flake-module.nix`, or `(import ./lib).mkModule`. The policy remains outside the input and import graph.

Behavior suites and their registry live in [tests/suites](../tests/suites/). The collection loader, check assembler, and check builder remain at the top of `tests/`. Shared node constructors and offline evaluation helpers live in [tests/helpers](../tests/helpers/). These helpers assemble the public flake exports with the supplied inputs, so the tests exercise the same exports consumers use. Concrete fixture modules and evaluated scenarios live in [tests/fixtures](../tests/fixtures/). Examples remain in `examples/` and run through the suites.

## Compatibility checks

Policy `v0.5` bundles a stable and an unstable nixpkgs pin with each release. CI runs the root `nix flake check` with the locked nixpkgs and with each pin through a native `--override-input nixpkgs` on both Linux systems. Each run requires nonempty host checks and fails if the run changes the project sources or `flake.lock`. The pins stay outside the project lock and consumer dependency graphs, so the root lock records the development default independently. [ADR-0005](adr/0005-separate-nixpkgs-selection-from-compatibility-coverage.md) records this boundary.

Run the policy's `test` command locally from the repository root; each run covers the host system:

```bash
nix run github:petohorvath/nixos-project-policy/v0.5 -- test . --nixpkgs locked
nix run github:petohorvath/nixos-project-policy/v0.5 -- test . --nixpkgs stable
nix run github:petohorvath/nixos-project-policy/v0.5 -- test . --nixpkgs unstable
```

Nix may reuse cached builds; a successful result does not mean every test process executed again.

For a focused investigation at another exact revision, set `NIXPKGS_REV` to its full commit and use a native override:

```bash
nix flake check --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --print-build-logs
```

The override deliberately changes the effective input graph without writing the lock. Use `--no-update-lock-file` alone, without an override or `--no-write-lock-file`, to validate the committed default. An arbitrary override is an investigation result, not a policy result.

## Focused checks

Root `nix flake check --no-update-lock-file --print-build-logs` runs the complete test collection through `checks.<system>.tests`, alongside formatting and lint. For a focused run, use nix-unit from the default development shell at the repository root:

```bash
nix-unit tests/entrypoint.nix --attr merging
nix-unit tests/entrypoint.nix --attr destinations.testRejectsMissingDestination
nix-unit tests/entrypoint.nix --attr destinations.testRejectsUnregisteredDestination
```

A suite name selects its descendants; a full test name selects one case. Every selected case includes its value or error expectations, including required message fragments. nix-unit handles discovery, selection, comparisons, error matching, and reporting. It reads the current checkout, so edits to tests are available without re-entering the shell. Track new files with `git add` before Git-backed flake evaluation.

[tests/entrypoint.nix](../tests/entrypoint.nix) loads the complete collection with the root locked inputs by default. The root [locked input](../flake.lock), `nixpkgs`, selects NixOS 26.05. The loader returns test definitions from `tests/suites/default.nix`; evaluating it alone does not verify expectations. `tests/checks.nix` wraps nix-unit in a Nix build. `tests/default.nix` registers that build alongside formatting and lint checks; `dev/checks.nix` exposes the assembled checks through the dev partition. Raw configurations under [tests/fixtures](../tests/fixtures/) are private inputs to the suites.

For a focused investigation at another exact revision, set `NIXPKGS_REV` to its full commit and select it for both the development tools and the test loader:

```bash
nix develop --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --command \
  nix-unit tests/entrypoint.nix --attr merging \
  --arg nixpkgs "(builtins.getFlake \"github:NixOS/nixpkgs/$NIXPKGS_REV\")"
```

The shell override selects the tools; the explicit argument selects the tested configurations and the nixpkgs library used by flake-parts. Neither command writes the lock. A focused run does not replace the full root check or the policy test runs.

### Test definitions

[tests/suites/default.nix](../tests/suites/default.nix) registers suites by behavior. Each test name starts with `test` and pairs `expr` with `expected`, or with native nix-unit `expectedError` for a rejection case. Declare the expected error type and message pattern beside the expression. The private [message-pattern helper](../tests/helpers/message-pattern.nix) builds a regex requiring every supplied literal fragment, in any order and across line breaks:

```nix
testRejectsMissingDestination = {
  expr = destinationRejections.missingDestination;
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

The [CI workflow](../.github/workflows/check.yml) calls shared policy `v0.5` through the moving minor-series tag and names its caller job `Policy`. It sets no inputs, so the policy runs on its default systems, `x86_64-linux` and `aarch64-linux`. The project has no VM tests and no additional required checks. Policy code stays outside the flake inputs and build graph.

The policy's `Check` job applies the input and public-output rules, starts the default development shell, and evaluates the formatter. Its `Tests` jobs run the root checks as described in [Compatibility checks](#compatibility-checks); formatting and lint run there as project-owned root checks. Run the same check locally from the repository root:

```bash
nix run github:petohorvath/nixos-project-policy/v0.5 -- check .
```

Nix caches the `v0.5` reference for up to an hour; add `--refresh` after `nix run` to use a patch release published within that time.

Require these statuses on `main` for both systems:

- `Policy / Check (<system>)`
- `Policy / Tests (locked, <system>)`
- `Policy / Tests (stable, <system>)`
- `Policy / Tests (unstable, <system>)`

`Policy / VM tests` appears as a skipped job and is not required. The workflow's `Plan` job writes the required statuses to its step summary.

Policy patch releases move `v0.5` and carry pin bumps and fixes without a caller change. A new minor series marks breaking rule changes; adopting it requires updating the workflow reference, the policy links, and the local commands together. Passing local checks does not configure GitHub settings or authorize a merge.
