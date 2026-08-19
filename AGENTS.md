# Agent Instructions

## Invocation policy

The `grilling` skill and composite skills that route into it may only be used after explicit human invocation. Do not start a grilling session from model judgment alone.

## Agent skills

### Issue tracker

Issues and PRDs for this repo live in GitHub Issues. See `docs/agents/issue-tracker.md`.
GitHub issue implementation work must use an issue-scoped branch and merge back into `master` through a pull request.

### Triage labels

This repo uses the default triage label vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This repo uses single-context domain docs: one root `CONTEXT.md` plus system-wide ADRs in `docs/adr/`. See `docs/agents/domain.md`.

## Server export policy

When code changes could affect the dedicated server, Docker image, multiplayer runtime, game rules, or exported resources, refresh the local server export before any Docker run, deploy check, or final handoff.

Run:

```bash
godot4 --headless --path . --export-release "Linux (server)" "Server Export/MP Hot Rum.x86_64"
```

This should regenerate:

- `Server Export/MP Hot Rum.x86_64`
- `Server Export/MP Hot Rum.pck`

Do not commit `Server Export/` artifacts unless the task explicitly includes release/export artifact updates. Always report whether the server export was refreshed or skipped.
