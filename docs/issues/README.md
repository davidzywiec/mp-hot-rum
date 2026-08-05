# Issue Drafting

Use this area to draft GitHub Issues before publishing them with `gh`.

## Create a Draft

Copy `docs/issues/templates/agent-task.md` into `docs/issues/drafts/` and fill it in.

## Publish a Draft

```bash
gh issue create \
  --title "Pick Feature Bug" \
  --label ready-for-agent \
  --body-file "docs/issues/drafts/UI - Update the UI to have this type of theme.md"
```

Use `ready-for-agent` only when the issue is clear enough for an agent to implement without stopping for product decisions. Use `needs-triage` or `needs-info` for work that still needs clarification.

Drafts are local planning artifacts by default. Commit a draft only when you intentionally want that planning context preserved in the repo.
