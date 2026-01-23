extends Resource
class_name RoundRequirement

@export var game_round: int = 1 # Round number this requirement applies to.
@export var deal_count: int = 7 # Cards dealt per player for this round.
@export var sets_of_3: int = 0 # Number of 3-of-a-kind sets required.
@export var runs_of_4 : int = 0 # Number of 4-card runs required.
@export var runs_of_7 : int = 0 # Number of 7-card runs required.
@export var all_cards : bool = false # If true, all cards must be used to go out.


