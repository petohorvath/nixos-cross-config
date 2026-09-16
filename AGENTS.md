# Repository instructions

Before changing code, documentation, or workflows, read the [shared policy](https://github.com/petohorvath/nixos-project-policy/blob/6208eb8c11a338a96e07002dc45696a5e32abad8/POLICY.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [development instructions](docs/development.md).

Run root `nix fmt` and `nix flake check` for changes. Preserve the factory's receiver-supplied `lib` and plain-import use without development inputs. Report validation limits, including pending policy enrollment; passing local checks does not authorize a merge.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for `petohorvath/nixos-cross-config`. See `docs/agents/issue-tracker.md` before issue operations.

### Triage labels

The five default triage labels are used. See `docs/agents/triage-labels.md` before triage.

### Domain docs

Single-context layout: root `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md` before exploring the repo.
