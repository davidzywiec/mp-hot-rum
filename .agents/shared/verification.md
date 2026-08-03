# Verification

Use the narrowest verification that gives confidence for the touched area. If a check cannot be run locally, say so in the handoff.

## Baseline Checks

- `git status --short --branch`
- `git diff --stat`
- Review relevant diffs before handoff.

## Gameplay Checks

- Manually exercise the changed turn or scoring flow.
- Check invalid move rejection.
- Check round-end and game-end behavior when relevant.
- Use debug fixtures for deterministic hands when available.

## Networking Checks

- Run a local host/client flow when possible.
- Confirm host/server authority validates client requests.
- Confirm all handlers agree on message names and payload shapes.
- Inspect logs for missing methods, bad peer IDs, and stale state.

## Headless Gameplay Smoke Checks

These checks require a project-provided runner. Until the runner exists and passes, agents must report headless gameplay coverage as a gap.

- Start a local dedicated/headless server.
- Start the required local client peers or test harness.
- Connect clients to the server.
- Create or join a lobby.
- Start a game with deterministic setup when possible.
- Exercise at least one round-critical path: deal, turn start, pickup, discard, and turn advance.
- Capture server and client logs for failures.
- Report the exact command used and whether the check passed.

## UI Checks

- Open the changed scene in Godot when possible.
- Verify node paths, signals, and script references.
- Check the 1280x720 base layout.
- Check that buttons, prompts, cards, and score panels do not overlap or clip.

## Build and Release Checks

- Confirm export paths in `export_presets.cfg`.
- Confirm generated file names match deployment docs.
- Confirm server executable/script modes are correct.
- For Docker changes, inspect `docker-compose.yml` and `Dockerfile` together.
