# Contributing

Follow the [shared project policy](https://github.com/petohorvath/nixos-project-policy/blob/6208eb8c11a338a96e07002dc45696a5e32abad8/POLICY.md) and the local [development instructions](docs/development.md). The development guide records the migration's pending enrollment and hosted setup requirements.

## Changes

Work on a branch and open a PR with a Conventional Commit title, such as `fix: Preserve contribution source locations`. Describe the resulting behavior, compatibility effects, and validation. Run root `nix fmt` and `nix flake check`; both stable and unstable fixtures must continue to pass. Add meaningful regression coverage for behavior changes. The default checks do not run VMs.

Every merge needs human approval and passing required checks. Squash each PR to one Conventional Commit using its title. The maintainer may approve and merge without a second reviewer. Record explicit breaking changes in the title and changelog.

## Public contract

The public API is `lib.mkModule { name, nodes, optionPaths }`, the generated `crossConfig.nodes` declarations, and their documented contribution, validation, and merge behavior. The generated module uses the receiver's `lib`. Keep the factory usable through `(import ./flake.nix).outputs { }` without evaluating development inputs. Caller-owned node construction and deployment remain outside this library.

Root `devShells`, `formatter`, and `checks` provide development entrypoints. Root `lib.tests` and `lib.failures` expose focused fixtures. `nixosConfigurations` evaluates the documented example. The flake's development inputs may enter consumer lock graphs; consumers may override them while keeping one nixpkgs revision within each node collection.

## Releases

Use independent Semantic Versioning tags and [CHANGELOG.md](CHANGELOG.md). No release tags exist yet; choose the initial version in a release PR. For later 0.x releases, breaking changes require a minor bump and patch releases remain compatible. Document migration steps whenever a public contract changes and decide readiness for 1.0 explicitly.

A release PR specifies the version, changelog, and migration notes. Human merge authorizes publication only after checks pass on the release commit. Ordinary merges do not publish releases, and existing release tags remain immutable.

## License

Original project code uses the [MIT license](LICENSE). Preserve copyright notices and third-party licensing or upstream package metadata when adding external material.
