# Project Context

MP Hot Rum is a Godot multiplayer card game. The codebase uses GDScript, Godot scene files, autoload singletons, data resources, and exported client/server artifacts.

## Current Shape

- Game scenes live under `scenes/game/`.
- Menu and lobby scenes live under `scenes/menu/` and `scenes/lobby/`.
- Runtime game systems live under `autoload/`.
- Network handlers live under `scripts/network/`.
- Ruleset and scoring data live under `data/rulesets/` and `data/scoring/`.
- Debug fixtures live under `data/debug/`.
- Export and deployment files live under `Client Export/`, `Server Export/`, `export_presets.cfg`, and `SERVER_DEPLOYMENT.md`.

## Architectural Biases

- The authoritative side should validate gameplay state changes.
- UI should present state and request actions; it should not invent authoritative game outcomes.
- Godot scene files are fragile. Keep scene edits focused and review script node paths after changing `.tscn` files.
- Generated export artifacts are large and should be committed only when the task explicitly calls for refreshed exports.
- Prefer small, reviewable changes over sweeping scene/script rewrites.

## Common Risk Areas

- Node path drift between `.tscn` files and scripts.
- RPC/message payloads changing in one handler but not another.
- Client-side actions mutating state before authority validates them.
- Debug helpers leaking into normal gameplay.
- Export paths changing without matching release documentation.
