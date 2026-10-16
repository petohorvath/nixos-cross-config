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

Root `nix flake check` runs the unit and integration suites through nix-unit as `checks.<system>.unit` and `checks.<system>.integration`, alongside formatting, statix, deadnix, and workflow validation against the selected `nixpkgs` input. The test entries include value comparisons, expected errors, and diagnostic context. nix-unit returns a failing exit status for any unmet expectation. The [nix-unit runner](../tests/runners/nix-unit.nix) starts one nix-unit process for each group of tests to bound evaluator memory, using store-path inputs and a temporary writable evaluation store inside the build sandbox. The writable store is needed because NixOS evaluation creates derivations and other store paths. The integration entry runs at most two processes at once, because a group of NixOS evaluations can peak above 3 GiB. The project has no build or VM tests.

The ordinary flake checker evaluates applicable shell and formatter outputs and builds every declared check for the host system. The test suites evaluate the examples, including their system derivation paths, without building example systems. The selected input supplies tools and configurations throughout that evaluation.

[Root `flake.nix`](../flake.nix) returns `mkFlake` directly, declaring the supported systems, `nixosModules.default`, `flakeModules.default`, and `lib`. Its `dev` partition supplies `checks`, `devShells`, and `formatter` through [dev/default.nix](../dev/default.nix). [The shell](../dev/shell.nix) and [formatter](../dev/formatter.nix) declare their package dependencies through `pkgs.callPackage`; [development composition](../dev/default.nix) supplies the selected inputs explicitly to the [development checks](../dev/checks.nix), which own the formatting and lint entries and add the test entries from the [test assembler](../tests/default.nix). [Treefmt configuration](../dev/treefmt.toml) lives beside the formatter. The root library exports contain no focused fixtures or example nodes. Plain Nix consumers use `nixos/module.nix`, `flake-module.nix`, or `(import ./lib).mkModule`. The policy remains outside the input and import graph.

[Unit suites](../tests/unit/) evaluate the code with `lib.evalModules` and follow the source layout: `tests/unit/nixos/module.nix` tests `nixos/module.nix`, `lib.nix` tests `lib/default.nix`, and `settings.nix` tests `lib/settings.nix`; `tagged-destinations.nix` covers behavior across several source files. [Integration suites](../tests/integration/) evaluate the code inside NixOS through `nixosSystem` or inside flake-parts, and are named after the feature they exercise. Each kind's `default.nix` is its entry point and lists its suites by hand. [tests/test-context.nix](../tests/test-context.nix) builds the single argument every suite receives. It imports the code from source, as plain Nix consumers do, so the unit suites evaluate no flake; the `flake-outputs` integration suite checks that the flake exposes the same code. Shared node constructors and offline evaluation helpers live in [tests/helpers](../tests/helpers/). Concrete fixture modules and evaluated scenarios live in [tests/fixtures](../tests/fixtures/). Examples remain in `examples/` and run through the integration suites.

## Compatibility checks

The root lock records the development default. CI also runs the root checks against the shared policy's stable and unstable nixpkgs pins, as [CI and policy](#ci-and-policy) describes. [ADR-0005](adr/0005-separate-nixpkgs-selection-from-compatibility-coverage.md) records this boundary.

For a focused investigation at another exact revision, set `NIXPKGS_REV` to its full commit and use a native override:

```bash
nix flake check --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --print-build-logs
```

The override deliberately changes the effective input graph without writing the lock. Use `--no-update-lock-file` alone, without an override or `--no-write-lock-file`, to validate the committed default. An arbitrary override is an investigation result, not a policy result.

## Focused checks

Root `nix flake check --no-update-lock-file --print-build-logs` runs every test through `checks.<system>.unit` and `checks.<system>.integration`, alongside formatting and lint. Build one entry with `nix build .#checks.<system>.unit` or `.#checks.<system>.integration`. For a focused run, use nix-unit from the default development shell at the repository root:

```bash
nix-unit tests/unit --attr settings
nix-unit tests/integration --attr merging
nix-unit tests/integration --attr destinations.testRejectsMissingDestination
nix-unit tests/integration --attr destinations.testRejectsUnregisteredDestination
```

A suite name selects its descendants; a full test name selects one case. Every selected case includes its value or error expectations, including required message fragments. nix-unit handles discovery, selection, comparisons, error matching, and reporting. It reads the current checkout, so edits to tests are available without re-entering the shell. Track new files with `git add` before Git-backed flake evaluation.

The entry points [tests/unit/default.nix](../tests/unit/default.nix) and [tests/integration/default.nix](../tests/integration/default.nix) take each input they evaluate as an argument, defaulting to the root locked inputs. The root [locked input](../flake.lock), `nixpkgs`, selects NixOS 26.05. The integration entry point rebuilds `flake-parts` against the selected `nixpkgs`. The entry points return test definitions; evaluating them alone does not verify expectations. [tests/runners/nix-unit.nix](../tests/runners/nix-unit.nix) wraps nix-unit in a Nix build, passing the flake's inputs as store paths. `tests/default.nix` returns the test entries; `dev/checks.nix` adds formatting and lint and exposes the checks through the dev partition. Raw configurations under [tests/fixtures](../tests/fixtures/) are private inputs to the suites.

For a focused investigation at another exact revision, set `NIXPKGS_REV` to its full commit and select it for both the development tools and the test loader:

```bash
nix develop --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --command \
  nix-unit tests/integration --attr merging \
  --arg nixpkgs "(builtins.getFlake \"github:NixOS/nixpkgs/$NIXPKGS_REV\")"
```

The shell override selects the tools; the explicit argument selects the tested configurations and the nixpkgs library used by flake-parts. Neither command writes the lock. A focused run does not replace the full root check or the policy test runs.

### Test definitions

Each entry point lists its suites by hand, with attribute names that match the file names; a suite file missing from the list does not run. Each test name starts with `test` and pairs `expr` with `expected`, or with native nix-unit `expectedError` for a rejection case. Declare the expected error type and message pattern beside the expression. The private [message-pattern helper](../tests/helpers/message-pattern.nix) builds a regex requiring every supplied literal fragment, in any order and across line breaks:

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

The node helpers exercise `nixosModules.default` through a plain import of `nixos/module.nix`. [Module](../tests/unit/nixos/module.nix) and [setting](../tests/unit/settings.nix) suites cover receiver-supplied `lib`, reciprocal contributions, shared registrations, normalization, priorities, required settings, and lazy collections. [Constructor tests](../tests/unit/lib.nix) cover `lib.mkModule`. The [flake-outputs suite](../tests/integration/flake-outputs.nix) checks that the flake exports the same files that the suites import.

[Flake-module tests](../tests/integration/flake-module.nix) assemble consumers with flake-parts through a plain import of `flake-module.nix` and cover default and explicit collections, shared settings, node defaults, plain imports, and invalid settings. The selected flake-parts library follows the same nixpkgs revision as the evaluated nodes. The example suites evaluate system derivation paths without building example systems.

[Destination](../tests/integration/destinations.nix) and tagged-destination ([unit](../tests/unit/tagged-destinations.nix), [integration](../tests/integration/tagged-destinations.nix)) suites pair accepted configurations with rejection cases for missing, read-only, incompatible, and conflicting destinations. Their error expectations verify contribution identities, destination paths, and source filenames. [Merging](../tests/integration/merging.nix), [priorities](../tests/integration/priorities.nix), [nested properties](../tests/integration/nested-properties.nix), and [forwarding](../tests/integration/forwarding.nix) include conflict, type, and contributed-assertion rejection cases beside successful behavior. [Reciprocal](../tests/integration/reciprocal.nix) and tagged-destination tests require native recursion errors only for actual value-dependency cycles. The [destination inspection design](destination-inspection.md) explains the receiver-local metadata evaluation.

## CI and policy

The [CI workflow](../.github/workflows/check.yml) calls the [shared project policy](https://github.com/petohorvath/nixos-project-policy/blob/v0.6/POLICY.md) in a job named `Policy`. The workflow's `uses:` reference selects the policy release. Outside the changelog, that reference and the policy link in this paragraph are the only places that name the policy version; a policy upgrade updates both and adds a changelog entry.

The caller sets no inputs, so the policy runs on its default systems, `x86_64-linux` and `aarch64-linux`. The project has no VM tests. Policy code stays outside the flake inputs and build graph.

The policy checks the inputs, public outputs, development shell, and formatter. It also evaluates every root output and builds the `checks` entries with the locked nixpkgs and with its bundled stable and unstable nixpkgs pins, applied through a native `--override-input nixpkgs`. Formatting and lint run as project-owned `checks` entries. The policy skips an entry whose `requiredSystemFeatures` the runner lacks; no entry here declares any. A stable or unstable run whose revision equals that of an earlier run passes without building. The pins stay outside the project lock and consumer dependency graphs. To run the same checks locally, use the policy's `check .` and `test . --nixpkgs locked|stable|unstable` commands as its README describes.

The policy lists the statuses to require, and the workflow's `Plan` job writes them to its step summary on every run. Passing local checks does not configure GitHub settings or authorize a merge.
