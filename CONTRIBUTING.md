# Contributing

Follow the shared project policy linked from [CI and policy](docs/development.md#ci-and-policy) and the local [development instructions](docs/development.md).

## Changes

Work on a branch and open a PR with a Conventional Commit title, such as `fix: Preserve contribution source locations`. Describe the resulting behavior, compatibility effects, and validation. Run the root formatter and flake checks listed in the [development instructions](docs/development.md#prerequisites). Run the [policy's local checks](docs/development.md#ci-and-policy). Add meaningful regression coverage for behavior changes. The checks do not run VMs.

Every merge needs human approval and passing required checks. Squash each PR to one Conventional Commit using its title. The maintainer may approve and merge without a second reviewer. Record explicit breaking changes in the title and changelog.

Keep documentation focused on current usage, structure, and design. Record implementation and validation history in commits, PRs, and CI, and release-facing changes in the changelog.

## Public contract

The primary API is `nixosModules.default` with required `crossConfig.name`, `crossConfig.nodeConfigurations`, and `crossConfig.optionPaths` settings, plus the outgoing `crossConfig.contributions` option. `lib.mkModule` retains its required `name`, `nodes`, and `optionPaths` arguments as an adapter to the same implementation. Preserve the behavior documented in the [API reference](docs/api.md), including lazy collections, normalized shared registrations, and reserved roots. Both interfaces use the receiver's `lib`. Plain Nix consumers import `nixos/module.nix` or use `(import ./lib).mkModule` without evaluating development inputs. Node construction and deployment remain the caller's responsibility.

The `dev` partition provides root `devShells`, `formatter`, and `checks` using the selected `nixpkgs` input. The default shell provides `cross-config-fmt` and nix-unit. Root `checks.<system>.tests` and focused `nix-unit tests/entrypoint.nix --attr <suite-or-test>` runs use the same complete test collection, loaded through `tests/entrypoint.nix`. Keep value, error, and diagnostic expectations beside each named test; private fixtures stay lazy until the runner selects a case. Examples run through the test suites. Consumers may override `nixpkgs` or use `follows` while keeping one nixpkgs revision within each node collection. The shared policy's nixpkgs pins stay outside the project lock and consumer dependency graphs.

The optional `flakeModules.default` adapter declares shared path and collection settings at flake scope and provides the consumer's `nixosModules.crossConfig`. The configured module supplies `mkDefault` settings, uses the receiver's `lib`, and leaves identity and construction to each caller-owned node. Its collection defaults lazily to the consumer's `flake.nixosConfigurations`. Preserve direct access through `flake-module.nix` and keep standalone usage independent of flake-parts evaluation. Its development input follows the selected `nixpkgs` for `nixpkgs-lib`.

The root lock records the development default independently of the shared policy's nixpkgs pins. CI runs the shared policy as [CI and policy](docs/development.md#ci-and-policy) describes; keep the required GitHub statuses aligned with it. Report executed checks, cached results, and unverified systems separately; local success does not configure merge gates.

## Releases

Use independent Semantic Versioning tags and [CHANGELOG.md](CHANGELOG.md). No release tags exist yet; choose the initial version in a release PR. For later 0.x releases, breaking changes require a minor bump and patch releases remain compatible. Document migration steps whenever a public contract changes and decide readiness for 1.0 explicitly.

A release PR specifies the version, changelog, and migration notes. Human merge authorizes publication only after checks pass on the release commit. Ordinary merges do not publish releases, and existing release tags remain immutable.

## License

Original project code uses the [MIT license](LICENSE). Preserve copyright notices and third-party licensing or upstream package metadata when adding external material.
