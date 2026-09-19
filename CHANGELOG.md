# Changelog

## Unreleased

### Added

- Root development shells for x86_64 Linux and aarch64 Linux, with direnv activation and tools from the selected nixpkgs revision.
- Root formatting for Nix, shell, Markdown, YAML, and JSON, plus statix, deadnix, and workflow checks.
- A `cross-config-fmt` package exposing the root formatter executable.
- An immutable shared-policy CI caller, contributor guidance, release rules, and an MIT license for original code.

### Changed

- Explain usage with a complete README example and API summary, and move detailed behavior to a separate API reference.
- Move the development shell, checks, focused fixtures, and the example from `dev/flake.nix` to the root flake.
- **Breaking:** select root tools, fixtures, checks, and examples through one `nixpkgs` input; remove the channel component from focused test/failure paths and root check names. Root `nix flake check` validates the selected revision. Native input overrides select another revision for the complete root check interface without changing the committed default.
- Keep explicit `systems` bindings and public flake outputs, preserving the default nixpkgs revision in the root lock.
- Run evaluation fixtures in separate processes so default checks bound evaluator memory while preserving their JSON results.
- Select shared policy release `v0.1.1` for rules and CI while checking nixpkgs locks against current central shared pins.

### Removed

- The benchmark suite and remaining `dev/` directory, along with Python, Ruff, and GNU time development tooling.
- Completed implementation plans and separate review, research, and validation logs; retain current design explanations and architectural decisions.
- **Breaking:** the root `nixpkgs-unstable` input. Compatibility revisions are supplied through native root input overrides.

### Migration

Replace `nix develop ./dev` with root `nix develop`, and run root `nix fmt --no-update-lock-file` instead of formatting from `dev/`. The separate development flake has been removed. Root `nix flake check --no-update-lock-file` validates the committed `nixpkgs` default. For another exact selection, set `NIXPKGS_REV` to its full commit and run:

```bash
nix flake check --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV" \
  --no-write-lock-file --print-build-logs
```

Point root input overrides and `follows` at `nixpkgs`, including overrides previously named `stable`. Remove overrides for the removed `nixpkgs-unstable` input or its older `unstable` name. No compatibility-only input enters consumers' lock graphs.

Update focused paths as follows. Each new root path evaluates the selected `nixpkgs` input; use an input override when selecting another revision.

| Previous root path                          | New root path                     |
| ------------------------------------------- | --------------------------------- |
| `lib.tests.<system>.<channel>.<fixture>`    | `lib.tests.<system>.<fixture>`    |
| `lib.failures.<system>.<channel>.<fixture>` | `lib.failures.<system>.<fixture>` |
| `checks.<system>.<channel>`                 | `checks.<system>.evaluation`      |
| `checks.<system>.<channel>-diagnostics`     | `checks.<system>.diagnostics`     |
| `checks.<system>.<channel>-value-cycle`     | `checks.<system>.value-cycle`     |

For example, replace `.#checks.x86_64-linux.unstable-diagnostics` with `.#checks.x86_64-linux.diagnostics` and supply the exact unstable revision through `--override-input nixpkgs` and `--no-write-lock-file`. The `mkModule` signature, receiver-supplied `lib`, contribution semantics, and plain-import usage remain unchanged.

Required policy-owned stable and unstable checks on both Linux architectures need a supporting immutable policy release, coordinated project records, and observed required statuses. The selected `v0.1.1` workflow checks the committed default and cannot provide that override matrix. Follow the [compatibility and policy guidance](docs/development.md#compatibility-checks) for local reproduction and activation requirements.
