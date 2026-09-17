# Repository instructions

Before changing code, documentation, or workflows, read the [shared policy](https://github.com/petohorvath/nixos-project-policy/blob/v0.1.1/POLICY.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [development instructions](docs/development.md).

Run root `nix fmt` and `nix flake check` for changes. Preserve the returned module's receiver-supplied `lib` and access to `mkModule` through a plain Nix import without development inputs. Report validation limits; passing local checks does not authorize a merge.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for `petohorvath/nixos-cross-config`. See `docs/agents/issue-tracker.md` before issue operations.

### Triage labels

The five default triage labels are used. See `docs/agents/triage-labels.md` before triage.

### Domain docs

Single-context layout: root `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md` before exploring the repo.
