extends Resource
class_name Ruleset

@export var id: String = "default_ruleset" # Unique identifier for this ruleset.
@export var name: String = "Default Ruleset" # Display name for this ruleset.
@export var description: String = "A standard ruleset for hot rum." # Short summary shown to players.
@export var max_rounds: int = 8 # Total number of rounds in the ruleset.
@export var round_requirements: Array[Resource] = [] # Per-round requirements (RoundRequirement resources).

func get_round(round_number: int) -> Resource:
    # Find the requirement entry matching the given round number.
    for requirement in round_requirements:
        if requirement.game_round == round_number:
            return requirement
    return null
