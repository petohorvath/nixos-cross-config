# Changelog

## Unreleased

### Added

- Optional `flakeModules.default` for flake-parts consumers, with shared registrations and a lazy default collection from the consumer's `nixosConfigurations`. It provides `nixosModules.crossConfig` for explicit node imports, retaining caller-owned construction, per-node identities, receiver-supplied `lib`, and plain-import export access.
- `nixosModules.default` as the primary consumer interface, with required node identity, lazy node collection, and composable allowed-path options. Keep `lib.mkModule` as a compatibility adapter and retain plain-import access to both interfaces.
- Root development shells for x86_64 Linux and aarch64 Linux, with direnv activation and tools from the selected nixpkgs revision.
- Root formatting for Nix, shell, Markdown, YAML, and JSON, plus statix, deadnix, and workflow checks.
- A `cross-config-fmt` package exposing the root formatter executable.
- An immutable shared-policy CI caller, contributor guidance, release rules, and an MIT license for original code.

### Changed

- **Breaking:** reject allowed paths rooted at `crossConfig` or `_module` through both interfaces; nested attributes and tags with these names remain supported. Validate required settings and nonempty string-segment paths, and normalize duplicate registrations so contributions arrive once.
- Explain usage with a complete README example and API summary, and move detailed behavior to a separate API reference.
- Move the development shell, checks, focused fixtures, and the example from `dev/flake.nix` to the root flake.
- **Breaking:** select root tools, fixtures, checks, and examples through one `nixpkgs` input; remove the stable/unstable component from focused test/failure paths and root check names. Root `nix flake check` validates the selected revision. Native input overrides select another revision for the complete root check interface without changing the committed default.
- Keep explicit `systems` bindings and public flake outputs, preserving the default nixpkgs revision in the root lock.
- Run evaluation fixtures in separate processes so default checks bound evaluator memory while preserving their JSON results.
- Select shared policy release `v0.3.0` and its `Policy` caller, deriving required merge checks from the release and central architecture and VM records. Preserve independent root defaults, verified stable and unstable compatibility runs, and separate compliance, formatting/lint, and committed-default jobs.

### Removed

- The benchmark suite and remaining `dev/` directory, along with Python, Ruff, and GNU time development tooling.
- Completed implementation plans and separate review, research, and validation logs; retain current design explanations and architectural decisions.
- **Breaking:** the root `nixpkgs-unstable` input. Compatibility revisions are supplied through native root input overrides.

### Migration

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

Update focused paths as follows; `<selection>` is `stable` or `unstable`. Each new root path evaluates the selected `nixpkgs` input; use an input override when selecting another revision.

| Previous root path                            | New root path                     |
| --------------------------------------------- | --------------------------------- |
| `lib.tests.<system>.<selection>.<fixture>`    | `lib.tests.<system>.<fixture>`    |
| `lib.failures.<system>.<selection>.<fixture>` | `lib.failures.<system>.<fixture>` |
| `checks.<system>.<selection>`                 | `checks.<system>.evaluation`      |
| `checks.<system>.<selection>-diagnostics`     | `checks.<system>.diagnostics`     |
| `checks.<system>.<selection>-value-cycle`     | `checks.<system>.value-cycle`     |

For example, replace `.#checks.x86_64-linux.unstable-diagnostics` with `.#checks.x86_64-linux.diagnostics` and supply the exact unstable revision through `--override-input nixpkgs` and `--no-write-lock-file`. The `mkModule` signature, receiver-supplied `lib`, contribution semantics, and plain-import usage remain unchanged.

Policy `v0.3.0` owns compatibility selection and execution while preserving the committed development default. Coordinate the central `policyVersion` with member release references. Mandatory status names, architectures, pins, and VM targets need no change from v0.2.0 solely for this upgrade. Put project-specific gates in `additionalRequiredChecks` and retain a complete generated `requiredChecks` list while any member still selects an older release. Verify the observed statuses and GitHub merge gates as part of adoption. Selecting the release in the member does not perform that central migration. Follow the [compatibility and policy guidance](docs/development.md#compatibility-checks) for the external runner, exact-result replay, and activation requirements.
