# Domain docs

This repo uses a single-context layout:

```text
CONTEXT.md
docs/adr/
```

## Before exploration

Read root `CONTEXT.md` and the ADRs in `docs/adr/` relevant to the task.

Skip missing files silently. The `domain-modeling` skill creates domain documentation lazily when terminology or decisions are resolved.

## Vocabulary

Use the glossary's terms in issue titles, proposals, hypotheses, and test names. Reconsider unfamiliar terminology; record missing concepts for `domain-modeling`.

## ADR conflicts

Identify contradictions with existing ADRs and explain the reason for reopening the decision.

> Conflicts with ADR-<number> (<title>): <proposed change and reason to revisit>.
