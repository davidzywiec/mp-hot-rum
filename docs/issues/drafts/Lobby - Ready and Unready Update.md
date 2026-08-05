# Goal
In the main menu when a player selects Ready it makes the outline of their profile green. I would like it to make the outline red if they are not ready. I would also like the ready button to change label to "Not Ready" when they are ready and change back to "Ready" when they are not ready. This is a visual indicator to the player that they are ready or not ready.

## Current behavior

When a player selects Ready in the main menu, the outline of their profile becomes green. However, there is no visual indicator for when they are not ready.

## Desired behavior

When a player selects Ready in the main menu, the outline of their profile should become green. When they are not ready, the outline should be red. Additionally, the ready button should change its label to "Not Ready" when they are ready and change back to "Ready" when they are not ready. This will provide a clear visual indicator to the player of their readiness status.

## Scope


## Acceptance criteria

- [ ] The outline of the player's profile should be green when they are ready and red when they are not ready.
- [ ] The ready button should change its label to "Not Ready" when the player is ready and change back to "Ready" when they are not ready.
- [ ] The visual indicators should be clear and easily distinguishable for the player.

## Verification

The player selects Ready in the main menu and observes the outline of their profile and the label of the ready button. The outline should be green when they are ready and red when they are not ready. The ready button should change its label accordingly.

- `scripts/qa/headless_gameplay_smoke.sh`
- manual host/client flow
- Godot scene opens without script errors

## Notes

No Notess
