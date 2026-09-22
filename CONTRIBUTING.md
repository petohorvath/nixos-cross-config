# Contributing

Follow the [shared project policy](https://github.com/petohorvath/nixos-project-policy/blob/v0.3.0/POLICY.md) and the local [development instructions](docs/development.md).

## Changes

Work on a branch and open a PR with a Conventional Commit title, such as `fix: Preserve contribution source locations`. Describe the resulting behavior, compatibility effects, and validation. Run root `nix fmt --no-update-lock-file` and `nix flake check --no-update-lock-file`. Run the [policy compatibility runner](docs/development.md#compatibility-checks) for the approved stable and unstable revisions from one trusted record snapshot. Add meaningful regression coverage for behavior changes. The checks do not run VMs.

Every merge needs human approval and passing required checks. Squash each PR to one Conventional Commit using its title. The maintainer may approve and merge without a second reviewer. Record explicit breaking changes in the title and changelog.

Keep documentation focused on current usage, structure, and design. Record implementation and validation history in commits, PRs, and CI, and release-facing changes in the changelog.

## Public contract

The primary API is `nixosModules.default` with required `crossConfig.name`, `crossConfig.nodeCollection`, and `crossConfig.optionPaths` settings, plus the outgoing `crossConfig.nodes` option. `lib.mkModule` retains its required `name`, `nodes`, and `optionPaths` arguments as an adapter to the same implementation. Preserve the behavior documented in the [API reference](docs/api.md), including lazy collections, normalized shared registrations, and reserved roots. Both interfaces use the receiver's `lib` and remain usable through `(import ./flake.nix).outputs { }` without evaluating development inputs. Node construction and deployment remain the caller's responsibility.

Root `devShells`, `formatter`, and `checks` provide development entrypoints using the selected `nixpkgs` input. The `cross-config-fmt` executable is available in the default shell. Root `lib.tests.<system>.<fixture>` exposes focused nix-unit suites; `lib.failures.<system>.<fixture>` exposes raw, lazy failure fixtures. `nixosConfigurations` evaluates the documented example. Consumers may override `nixpkgs` or use `follows` while keeping one nixpkgs revision within each node collection. Compatibility selections stay outside member lockfiles and consumer dependency graphs.

The optional `flakeModules.default` adapter declares shared path and collection settings at flake scope and provides the consumer's `nixosModules.crossConfig`. The configured module supplies `mkDefault` settings, uses the receiver's `lib`, and leaves identity and construction to each caller-owned node. Its collection defaults lazily to the consumer's `flake.nixosConfigurations`. Preserve plain-import access to the adapter export and keep standalone usage independent of flake-parts evaluation. Its development input follows the selected `nixpkgs` for `nixpkgs-lib`.

The root lock records the development default independently of the policy compatibility pair. Policy release `v0.3.0` supplies verified compatibility runs and separate committed-default and development-tool checks. Keep member references, central records, and required GitHub statuses aligned through the [policy maintenance procedure](docs/development.md#ci-and-policy). Report executed checks, cached results, and unverified architectures or policy integration separately; local success does not record adoption or configure merge gates.

## Releases

Use independent Semantic Versioning tags and [CHANGELOG.md](CHANGELOG.md). No release tags exist yet; choose the initial version in a release PR. For later 0.x releases, breaking changes require a minor bump and patch releases remain compatible. Document migration steps whenever a public contract changes and decide readiness for 1.0 explicitly.

A release PR specifies the version, changelog, and migration notes. Human merge authorizes publication only after checks pass on the release commit. Ordinary merges do not publish releases, and existing release tags remain immutable.

## License

Original project code uses the [MIT license](LICENSE). Preserve copyright notices and third-party licensing or upstream package metadata when adding external material.
