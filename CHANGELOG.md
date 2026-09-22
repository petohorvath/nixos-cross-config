# Changelog

## Unreleased

### Added

- Optional `flakeModules.default` for flake-parts consumers, with shared registrations and a lazy default collection from the consumer's `nixosConfigurations`. It provides `nixosModules.crossConfig` for explicit node imports, retaining caller-owned construction, per-node identities, receiver-supplied `lib`, and direct access through `flake-module.nix`.
- `nixosModules.default` as the primary consumer interface, with required node identity, lazy node collection, and composable allowed-path options. Keep `lib.mkModule` as a compatibility adapter and retain plain-import access to both interfaces.
- Root development shells for x86_64 Linux and aarch64 Linux, with direnv activation and tools from the selected nixpkgs revision.
- Root formatting for Nix, shell, Markdown, YAML, and JSON, plus statix, deadnix, and workflow checks.
- An immutable shared-policy CI caller, contributor guidance, release rules, and an MIT license for original code.

### Changed

- **Breaking:** reject allowed paths rooted at `crossConfig` or `_module` through both interfaces; nested attributes and tags with these names remain supported. Validate required settings and nonempty string-segment paths, and normalize duplicate registrations so contributions arrive once.
- Explain usage with a complete README example and API summary, and move detailed behavior to a separate API reference.
- Return `mkFlake` directly from the root flake, with public module and library exports declared there. Keep shell, formatter, treefmt, and check assembly configuration in a `dev` partition, preserving root development commands and `.envrc`.
- **Breaking:** select tools, fixtures, checks, and examples through one root `nixpkgs` input; remove stable/unstable labels from focused fixtures and root check names. Test runners still accept `nixpkgs` explicitly. Root `nix flake check` validates the selected revision. Native input overrides select another revision for the complete root check interface without changing the committed default.
- Keep explicit `systems` bindings and public flake outputs, preserving the default nixpkgs revision in the root lock.
- Run named value comparisons, expected errors, native recursion cases, and diagnostic message assertions through one native nix-unit collection.
- **Breaking (development interface):** replace separate evaluation, diagnostic, and value-cycle check outputs with `checks.<system>.tests`. The development shell provides nix-unit for focused runs, including all assertions for each selected test. Rename the collection loader from `dev/fixtures.nix` to `dev/tests.nix` and remove its separate `tests` and `failures` trees. Rejection tests now require the intended error message as well as its type.
- Select shared policy release `v0.3.0` and its `Policy` caller, deriving required merge checks from the release and central architecture and VM records. Preserve independent root defaults, verified stable and unstable compatibility runs, and separate compliance, formatting/lint, and committed-default jobs.

### Removed

- **Breaking (development interface):** the redundant `packages.<system>.cross-config-fmt` output. The formatter remains available through `formatter.<system>`, `nix fmt`, and the default development shell.
- **Breaking:** plain-export access through `(import ./flake.nix).outputs { }`. Use direct module paths and `(import ./lib).mkModule`; the small constructor moves from `nixos/mk-module.nix` into `lib/default.nix`.
- **Breaking (development interface):** root `lib.tests`, `lib.failures`, and example `nixosConfigurations`. nix-unit loads suites from `dev/tests.nix`; raw scenarios become private fixtures and examples remain covered by the tests.
- The separate `dev/flake.nix` and its lockfile, the benchmark suite, and Python, Ruff, and GNU time development tooling.
- Completed implementation plans and separate review, research, and validation logs; retain current design explanations and architectural decisions.
- **Breaking:** the root `nixpkgs-unstable` input. Compatibility revisions are supplied through native root input overrides.

### Migration

Replace references to `packages.<system>.cross-config-fmt` with `formatter.<system>`. For example, replace `nix build .#cross-config-fmt` with `nix build .#formatter.x86_64-linux` on x86_64 Linux. Use root `nix fmt --no-update-lock-file` to format the project; the `cross-config-fmt` command remains available inside `nix develop`.

For focused tests, replace raw `failures.<fixture>` evaluations and old `dev/fixtures.nix` paths with `nix-unit dev/tests.nix --attr <suite-or-test>` inside the development shell. For example, use `nix-unit dev/tests.nix --attr merging.testHosts` or `nix-unit dev/tests.nix --attr merging.testRejectsLocalConflict`. Each selected case includes its expected value or error and required message fragments. `dev/tests.nix` is the collection loader; its definitions alone do not execute assertions. Root `nix flake check --no-update-lock-file --print-build-logs` remains the complete validation command. See [focused checks](docs/development.md#focused-checks) for exact-revision commands.

Replace plain-export access through `(import ./flake.nix).outputs { }` with direct entry points relative to the library checkout:

| Previous export        | Direct entry point                            |
| ---------------------- | --------------------------------------------- |
| `nixosModules.default` | `./nixos/module.nix` in NixOS `imports`       |
| `flakeModules.default` | `./flake-module.nix` in flake-parts `imports` |
| `lib.mkModule`         | `(import ./lib).mkModule`                     |

Flake consumers keep the same module and constructor exports. The library no longer exports example nodes; run `nix-unit dev/tests.nix --attr example` and `nix-unit dev/tests.nix --attr flakeModule.example` or construct nodes from the files in `examples/`.

Flake-parts consumers can opt into `flakeModules.default`, move shared registrations to flake-level `crossConfig.optionPaths`, and import `config.flake.nixosModules.crossConfig` in each node. Keep node identities and outgoing contributions at NixOS scope. Set flake-level `crossConfig.nodeCollection` for subsets or guests outside `nixosConfigurations`. Extend shared lists at flake scope; ordinary node-level definitions replace the adapter's `mkDefault` settings. This adapter is additive and requires no migration for standalone or constructor consumers. See the [flake-parts guide](docs/flake-parts.md).

Replace `crossConfig.lib.mkModule { inherit name nodes optionPaths; }` in a node's imports with `crossConfig.nixosModules.default`. Set `crossConfig.name = name`, `crossConfig.nodeCollection = nodes`, and `crossConfig.optionPaths = optionPaths` through ordinary modules. The constructor remains available for incremental migration; outgoing `crossConfig.nodes` syntax is unchanged.

Share the collection and registrations through common imported settings modules. Path lists follow normal priorities and merge before deduplication. Supply `[ ]` explicitly when no contributions are allowed. Registrations must be independent of receiving configuration; register service destinations unconditionally and condition contributions instead. See the [API reference](docs/api.md#allowed-option-paths) for literal segments, normalization, and dependency limits.

Move any destination rooted at `crossConfig` or `_module` beneath an ordinary receiving namespace and update its registrations and contributors. This restriction applies even through the compatibility adapter and to unused paths. Nested names are unaffected. The new export is additive, but the destination restriction is a breaking public-contract change; after an initial release, a 0.x release containing it requires a minor version bump.

Replace `nix develop ./dev` with root `nix develop`, and run root `nix fmt --no-update-lock-file` instead of formatting from `dev/`. The separate development flake has been removed. Root `nix flake check --no-update-lock-file` validates the committed `nixpkgs` default. For another exact selection, set `NIXPKGS_REV` to its full commit and run:

```bash
nix flake check --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --print-build-logs
```

Point root input overrides and `follows` at `nixpkgs`, including overrides previously named `stable`. Remove overrides for the removed `nixpkgs-unstable` input or its older `unstable` name. No compatibility-only input enters consumers' lock graphs.

Replace `checks.<system>.evaluation`, `checks.<system>.diagnostics`, and `checks.<system>.value-cycle` with `checks.<system>.tests`. Older check names containing `stable` or `unstable` also map to this single target. Select the nixpkgs revision through a native root input override, and select individual behaviors with nix-unit's `--attr` option.

For example, replace `.#checks.x86_64-linux.unstable-diagnostics` with `.#checks.x86_64-linux.tests` and supply the exact unstable revision through `--override-input nixpkgs` and `--no-write-lock-file`.

Policy `v0.3.0` owns compatibility selection and execution while preserving the committed development default. Coordinate the central `policyVersion` with member release references. Mandatory status names, architectures, pins, and VM targets need no change from v0.2.0 solely for this upgrade. Put project-specific gates in `additionalRequiredChecks` and retain a complete generated `requiredChecks` list while any member still selects an older release. Verify the observed statuses and GitHub merge gates as part of adoption. Selecting the release in the member does not perform that central migration. Follow the [compatibility and policy guidance](docs/development.md#compatibility-checks) for the external runner, exact-result replay, and activation requirements.
