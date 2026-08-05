# Goal

The current player whose turn it is to pickup the top card or pass should be able to minimize the popup and look at their hand and organize said hand. Then they should have the ability to maximize the popup and continue their turn.

## Current behavior

Right now the player can only view the popup and cannot minimize it to view their hand. This is a problem because the player cannot see their hand and organize it while deciding whether to pickup the top card or pass.

## Desired behavior

The player should be able to minimize the popup and view their hand while deciding whether to pickup the top card or pass. The player should also be able to maximize the popup and continue their turn. When the popup is minimized, the player should easily see where to maximize the popup again. Maybe a small glow effect around a button to bring the popup back up.

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
