# MP Hot Rum

MP Hot Rum is a multiplayer card game with server-authoritative turn flow, discard-pile interaction, meld play, round progression, scoring, and game completion.

## Language

**Lobby**:
The pre-Game space where players join, set readiness, and the host starts the Game. At least two players must be present before the Game can start.
_Avoid_: Start screen, waiting room

**Game**:
A complete play session that starts from the Lobby, runs through the configured Rounds, and ends when final scoring determines the winner.
_Avoid_: Match, session

**Round**:
One configured requirement step inside a Game. Players repeat Turn Flow until one player ends the Round, then scoring is applied before the next Round or Game End.
_Avoid_: Hand, level, phase

**Game End**:
The end of the final Round after scoring determines the winner. Final scoring is displayed at Game End.
_Avoid_: Game over, match end

**Play Again**:
The Game End choice where connected players agree to start a new Game together.
_Avoid_: Restart, rematch

**Going Out**:
Ending the Round by having no cards left in hand. A player can Go Out by discarding their final card or by using Add to Existing Melds for all remaining cards.
_Avoid_: Finishing, round completion

**Hand**:
The cards a player currently holds privately during a Round.
_Avoid_: Player cards, private cards

**Discard Pile**:
The face-up pile of discarded cards. The top card may be taken by the current player or claimed by an eligible non-turn player during the Claim Window.
_Avoid_: Pile, pickup pile

**Deck**:
The face-down cards players draw from during a Round.
_Avoid_: Draw pile, stock pile

**Current Player**:
The player whose current turn it is and whose Turn Flow is active.
_Avoid_: Active player, turn player

**Non-turn Player**:
A player who is not the Current Player. Eligible Non-turn Players may claim or pass during the Claim Window.
_Avoid_: Other player, inactive player

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
