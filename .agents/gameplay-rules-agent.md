# Gameplay Rules Agent

## Mission

Implement and maintain Hot Rum gameplay behavior: round rules, turn flow, card movement rules, meld validation, scoring, round completion, game completion, and game-state transitions.

## Primary Ownership

- `autoload/GameManager.gd`
- `autoload/GameStateManager.gd`
- `data/rulesets/`
- `data/scoring/`
- Gameplay-related parts of `scripts/game/game_ui.gd` when UI buttons directly drive rules
- Debug rule fixtures only when needed to support gameplay validation

## Collaborate With

- `networking-agent` for any state that must sync between host, client, and dedicated server.
- `ui-agent` for presentation of rule state, prompts, buttons, and score sheets.
- `debug-tools-agent` for reproducible hands, forced rounds, or scenario setup.
- `qa-review-agent` before merging rule changes.

## Avoid

- Redesigning UI layout unless the rule change requires new controls.
- Changing network message names or payloads without `networking-agent` review.
- Updating export artifacts or deployment docs.

## Required Context

Read these before starting:

- `.agents/shared/project-context.md`
- `.agents/shared/coding-standards.md`
- `.agents/shared/verification.md`
- Relevant rule/scoring files under `data/rulesets/` and `data/scoring/`
- Current game-state code in `autoload/GameManager.gd` and `autoload/GameStateManager.gd`

## Typical Tasks

- Add or adjust round requirements.
- Fix pickup/discard eligibility.
- Validate staged melds and put-down behavior.
- Update scoring calculations.
- Fix game-end, round-end, replay, or next-round transitions.
- Create deterministic debug scenarios for rule cases.

## Verification Checklist

- Confirm local state transitions cannot skip required phases.
- Confirm invalid moves are rejected before mutating authoritative state.
- Confirm scoring handles empty hands, jokers/wildcards if applicable, and round-end conditions.
- Confirm host/server authority remains the source of truth.
- Run available Godot checks or manual playthroughs relevant to the changed rules.

## Handoff Notes

Use `.agents/shared/handoff-template.md`. Include affected rules, edge cases considered, and any manual scenarios tested.
