# MP Hot Rum

MP Hot Rum is a multiplayer card game with server-authoritative turn flow, discard-pile interaction, meld play, round progression, scoring, and game completion.

## Language

**Turn Flow**:
The sequence for a player's turn, including choosing a pickup source, resolving any Claim Window, playing melds when allowed, discarding, and advancing play.
_Avoid_: Turn action, action flow

**Claim Window**:
The opportunity for non-turn players to claim or pass on the discard pile card after the current player declines it by drawing from the deck. A player cannot claim the card they just discarded.
_Avoid_: Pickup window, pass window

**Claim Penalty**:
The extra card a non-turn player draws when they claim the discard pile card during the Claim Window.
_Avoid_: Extra draw, penalty draw
