# Changelog

## Unreleased

### Added

- Root development shells for x86_64 Linux and aarch64 Linux, with direnv activation and stable development tools.
- Root formatting for Nix, shell, Markdown, YAML, and JSON, plus statix, deadnix, and workflow checks.
- A `cross-config-fmt` package exposing the root formatter executable.
- An immutable shared-policy CI caller, contributor guidance, release rules, and an MIT license for original code.

### Changed

- Move development inputs, checks, focused fixtures, and the example from `dev/flake.nix` to the root flake, preserving both locked nixpkgs revisions.
- Name stable and unstable inputs `nixpkgs` and `nixpkgs-unstable`, with an explicit `systems` binding and public outputs in root `flake.nix`.
- Run evaluation fixtures in separate processes so default checks bound evaluator memory while preserving their JSON results.
- Select shared policy release `v0.1.1` for rules and CI while checking nixpkgs locks against current central shared pins.

### Removed

- The benchmark suite and remaining `dev/` directory, along with Python, Ruff, and GNU time development tooling.
- Completed implementation plans and separate review, research, and validation logs; retain current design explanations and architectural decisions.

### Migration

Replace `nix develop ./dev`, `nix flake check ./dev`, and `./dev#...` references with root commands and `.#...`. Run root `nix fmt` instead of formatting from `dev/`. The separate development flake has been removed.

The root flake now declares development inputs, which can enter consumer lock graphs. Update any root input overrides or `follows` paths from `stable` to `nixpkgs` and from `unstable` to `nixpkgs-unstable`. Focused fixture and check channel names remain `stable` and `unstable`. The factory signature, receiver-supplied `lib`, contribution semantics, and plain-import usage remain unchanged.
