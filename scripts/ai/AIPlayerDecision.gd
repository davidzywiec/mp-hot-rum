extends RefCounted
class_name AIPlayerDecision

const DIFFICULTIES: Array[String] = ["Easy", "Medium", "Hard"]
const EASY_STRATEGY: GDScript = preload("res://scripts/ai/AIPlayerStrategy.gd")
const MEDIUM_STRATEGY: GDScript = preload("res://scripts/ai/MediumAIStrategy.gd")
const HARD_STRATEGY: GDScript = preload("res://scripts/ai/HardAIStrategy.gd")
const MELD_PLANNER: GDScript = preload("res://scripts/ai/AIMeldPlanner.gd")

static func is_valid_difficulty(difficulty: String) -> bool:
	return DIFFICULTIES.has(difficulty)

static func prepare_observation(observation: Dictionary) -> Dictionary:
	if bool(observation.get("turn_pickup_completed", false)) and not bool(observation.get("has_put_down", false)) and not bool(observation.get("claim_window_active", false)):
		observation["put_down_plan"] = MELD_PLANNER.find_plan(observation)
	if bool(observation.get("turn_pickup_completed", false)) and bool(observation.get("has_put_down", false)) and not bool(observation.get("claim_window_active", false)):
		var add_actions: Array = []
		for raw_card in observation.get("own_hand", []):
			var card_data: Dictionary = raw_card
			var card: Card = Card.from_dict(card_data)
			for raw_meld in observation.get("public_melds", []):
				var meld_data: Dictionary = raw_meld
				var validation: Dictionary = PutDownValidator.validate_card_for_meld_add(meld_data, card)
				if bool(validation.get("ok", false)):
					add_actions.append({"type": "add_to_meld", "meld_id": int(meld_data.get("meld_id", -1)), "card_data": card_data})
		observation["add_to_meld_actions"] = add_actions
	return observation

static func choose_action(observation: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var strategy: RefCounted = EASY_STRATEGY.new()
	match str(observation.get("difficulty", "Easy")):
		"Medium":
			strategy = MEDIUM_STRATEGY.new()
		"Hard":
			strategy = HARD_STRATEGY.new()
	return strategy.choose_action(observation, random)
