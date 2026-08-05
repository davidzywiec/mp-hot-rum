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

**Meld**:
A valid grouping of cards played face-up by a player. Sets and Runs are the official Meld subtypes.
_Avoid_: Group

**Set**:
A Meld of three or more cards with the same number.
_Avoid_: Three-of-a-kind

**Run**:
A Meld of four or more cards in the same suit and in ascending number order. Runs do not wrap around from King to Ace.
_Avoid_: Sequence

**Put Down**:
The first play in a Round where a player places the required Melds face-up and becomes eligible to add cards to existing Melds.
_Avoid_: Go down, lay down, initial meld

**Add to Existing Melds**:
A play where a player who has already Put Down adds one or more cards to existing face-up Melds.
_Avoid_: Add to meld, extend meld, append to meld
