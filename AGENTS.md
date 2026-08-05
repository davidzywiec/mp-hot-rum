# Agent Instructions

## Invocation policy

The `grilling` skill and composite skills that route into it may only be used after explicit human invocation. Do not start a grilling session from model judgment alone.

## Agent skills

### Issue tracker

Issues and PRDs for this repo live in GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

This repo uses the default triage label vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This repo uses single-context domain docs: one root `CONTEXT.md` plus system-wide ADRs in `docs/adr/`. See `docs/agents/domain.md`.
