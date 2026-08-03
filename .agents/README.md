# Agent Development Setup

This directory defines the project-specific agent roster for MP Hot Rum. Agents are organized by development responsibility so work starts with clear ownership, predictable context, and an explicit verification path.

## Agent Roster

- [gameplay-rules-agent](gameplay-rules-agent.md) owns card-game rules, scoring, round flow, meld validation, and game-end behavior.
- [networking-agent](networking-agent.md) owns multiplayer transport, RPC/message shape, authority boundaries, and dedicated-server behavior.
- [ui-agent](ui-agent.md) owns menus, lobby screens, in-game table UI, card presentation, and Godot scene/script wiring.
- [debug-tools-agent](debug-tools-agent.md) owns dev overlay features, fixture hands, local testing shortcuts, and reproducible debug scenarios.
- [build-release-agent](build-release-agent.md) owns exports, packaging, Docker/server deployment, release notes, and deployment docs.
- [qa-review-agent](qa-review-agent.md) reviews diffs for regressions, missing checks, authority mistakes, scene reference issues, and release risk.

## Shared References

Every implementation agent should read these first:

- [project-context](shared/project-context.md)
- [coding-standards](shared/coding-standards.md)
- [verification](shared/verification.md)
- [handoff-template](shared/handoff-template.md)

## Default Workflow

1. Choose one primary implementation agent based on the requested change.
2. Read the primary agent file and the shared references.
3. Keep edits inside the agent's ownership area unless the task genuinely crosses boundaries.
4. Ask the relevant secondary agent to review cross-boundary changes.
5. Have `qa-review-agent` review meaningful diffs before committing.
6. Commit with the owning agent and verification notes in the commit body when practical.

## Commit Body Convention

```text
Agent: gameplay-rules-agent
Review: qa-review-agent
Manual checks:
- Started host/client flow locally
- Verified pickup/discard turn state
```
