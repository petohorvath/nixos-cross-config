# Repository instructions

Before changing code, documentation, or workflows, read the [shared policy](https://github.com/petohorvath/nixos-project-policy/blob/v0.4.0/POLICY.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [development instructions](docs/development.md).

Validate changes by running the root formatter and flake checks exactly as the [development instructions](docs/development.md#prerequisites) write them; their flags keep the committed `flake.lock` unchanged. Preserve the returned module's receiver-supplied `lib` and access to `mkModule` through a plain Nix import without development inputs. Report validation limits; passing local checks does not authorize a merge.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for `petohorvath/nixos-cross-config`. See `docs/agents/issue-tracker.md` before issue operations.

### Triage labels

The five default triage labels are used. See `docs/agents/triage-labels.md` before triage.

### Domain docs

Single-context layout: root `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md` before exploring the repo.
