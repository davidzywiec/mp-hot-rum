# Coding Standards

## General

- Follow existing GDScript style in nearby files.
- Keep edits scoped to the requested behavior.
- Prefer explicit names for game phases, actions, and message payloads.
- Avoid unrelated refactors while fixing behavior.
- Add comments only when they explain non-obvious state or protocol decisions.

## Godot Scenes

- Update `.tscn` and paired script files together when adding nodes or signals.
- Verify node paths used by `@onready` variables and direct `$Path` references.
- Avoid incidental scene serialization churn when possible.
- Preserve resource IDs and script references unless a task requires changing them.

## Multiplayer

- Treat client inputs as requests, not facts.
- Validate turn ownership, card ownership, and phase eligibility before mutating shared state.
- Keep sender and receiver payloads in sync.
- Be explicit about host-only, client-only, and dedicated-server-only paths.

## Data and Resources

- Prefer data-driven rules in `data/rulesets/` and `data/scoring/` when extending configurable behavior.
- Keep debug fixtures under `data/debug/`.
- Do not mix debug-only resources into production flows without an explicit gate.

## Artifacts

- Commit `Client Export/` and `Server Export/` output only when the task is about release/export state.
- Report binary artifact changes in the handoff.
- Preserve executable file mode for server launcher/runtime files.
