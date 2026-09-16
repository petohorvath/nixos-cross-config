# Changelog

## Unreleased

### Added

- Root development shells for x86_64 Linux and aarch64 Linux, with direnv activation and stable development tools.
- Root formatting for Nix, shell, Markdown, YAML, JSON, and Python, plus statix, deadnix, Python lint, and workflow checks.
- An immutable shared-policy CI caller, contributor guidance, release rules, and an MIT license for original code.

### Changed

- Move development inputs, checks, focused fixtures, and the example from `dev/flake.nix` to the root flake, preserving both locked nixpkgs revisions.
- Resolve benchmark inputs from the root flake and GNU time from the development shell.
- Run evaluation fixtures in separate processes so default checks bound evaluator memory while preserving their JSON results.

### Migration

Replace `nix develop ./dev`, `nix flake check ./dev`, and `./dev#...` references with root commands and `.#...`. Run root `nix fmt` instead of formatting from `dev/`. The separate development flake has been removed.

The root flake now declares stable and unstable development inputs, which can enter consumer lock graphs. The factory signature, receiver-supplied `lib`, contribution semantics, and plain-import usage remain unchanged. Policy enrollment and pin approval remain pending; see [adoption status](docs/development.md#policy-adoption).
