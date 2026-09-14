# Issue tracker: GitHub

Issues and specs published to the issue tracker live in GitHub Issues for `petohorvath/nixos-cross-config`. Use the `gh` CLI from this clone; the remote selects the repository.

Write multi-line bodies and comments to temporary files and pass them with `--body-file`.

## Issue operations

| Operation | Command |
| --- | --- |
| Create / publish | `gh issue create --title "..." --body-file <file>` |
| Read / fetch a ticket | `gh issue view <number> --json number,title,body,labels,comments,assignees,state` |
| List | `gh issue list --state open --json number,title,body,labels,comments,assignees` |
| Comment | `gh issue comment <number> --body-file <file>` |
| Apply a label | `gh issue edit <number> --add-label "..."` |
| Remove a label | `gh issue edit <number> --remove-label "..."` |
| Close | `gh issue close <number>` |

Use `--label` and `--state` filters as needed. Set `--limit` high enough to include the relevant queue; the default list limit is 30. Filter structured comments with `--jq` when needed.

## Pull requests as a triage surface

**PRs as a request surface: no.**

GitHub issues and PRs share a number space. Resolve ambiguous references with `gh pr view <number>`, falling back to `gh issue view <number>`.

## Wayfinding operations

The `wayfinder` map is one issue with child issues as tickets.

- **Map**: create an issue labeled `wayfinder:map` with Notes, Decisions-so-far, and Fog sections.
- **Child ticket**: create an issue with `--parent <map-number>` and a `wayfinder:<type>` label (`research`, `prototype`, `grilling`, or `task`). If sub-issues are unavailable, add a task-list entry to the map and `Part of #<map>` to the child body.
- **Blocking**: use native dependencies: `gh issue edit <child-number> --add-blocked-by <blocker-number>`. If dependencies are unavailable, add `Blocked by: #<n>, #<n>` at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier**: read the map's children in map order. Refresh each child's state, assignees, and blockers with `gh issue view <number> --json state,assignees,blockedBy`; check each blocker's current state. Select the first open, unassigned child with no open blockers. For fallback links, read the map's task list and each child's `Blocked by` line.
- **Claim**: `gh issue edit <number> --add-assignee @me`, the wayfinding session's first write.
- **Resolve**: post the answer with `gh issue comment <number> --body-file <file>`, close the child, then append an answer summary and link to the map's Decisions-so-far. Preserve the rest of the map body.
