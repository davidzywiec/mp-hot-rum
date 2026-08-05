# Goal
Fix the bug that the user cannot maximize the popup after minimizing it. The user should be able to minimize the popup to view their hand and then maximize it again to continue their turn.

## Current behavior

Right now the player can minimize the popup to view their hand, but cannot maximize it again to continue their turn. This is a problem because the player cannot continue their turn after viewing their hand.

## Desired behavior

The player should be able to minimize the popup to view their hand and then maximize it again to continue their turn. When the popup is minimized, the player should easily see where to maximize the popup again. Maybe a small glow effect around a button to bring the popup back up.

## Scope


## Acceptance criteria

- [ ] TurnFlow Active Player can minimize the popup to view their hand
- [ ] TurnFlow Active Player can maximize the popup to continue their turn
- [ ] TurnFlow Active Player can see a visual indicator to maximize the popup when it is minimized
- [ ] TurnFlow Non-Active Players cannot see the popup at all.

## Verification

The Active Player moves a card in their hand and the card moves to the new position in their hand. The Active Player minimizes the popup and sees their hand. The Active Player maximizes the popup and continues their turn.

- `scripts/qa/headless_gameplay_smoke.sh`
- manual host/client flow
- Godot scene opens without script errors

## Notes

No Notess
