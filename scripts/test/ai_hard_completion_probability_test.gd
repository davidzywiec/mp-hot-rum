extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var own_hand: Array = [_card(0, 7), _card(1, 7)]
	var completing_discard: Dictionary = _card(2, 7)
	var possible_wild: Dictionary = _card(3, 2)
	var possible_dead_card: Dictionary = _card(3, 13)
	var history: Array = []
	for suit in range(4):
		for number in range(1, 14):
			var card: Dictionary = _card(suit, number)
			if own_hand.has(card) or [completing_discard, possible_wild, possible_dead_card].has(card):
				continue
			history.append({"event": "discard", "card": card, "peer_id": 22})
	history.append({"event": "discard", "card": completing_discard, "peer_id": 22})
	var observation: Dictionary = {
		"peer_id": 11,
		"current_player_peer_id": 11,
		"turn_pickup_completed": false,
		"own_hand": own_hand,
		"discard_top": completing_discard,
		"deck_count": 2,
		"deck_copies": 1,
		"player_count": 2,
		"round_requirement": {"sets_of_3": 1},
		"public_card_history": history,
		"public_melds": [],
		"heuristic_weights": {"set": 0.0, "wild": 1.0},
		"simulation_budget": 256
	}
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 4
	var action: Dictionary = HardAIStrategy.new().choose_action(observation, random)
	if action.get("type", "") != "take_from_pile":
		printerr("[AI_HARD_COMPLETION_PROBABILITY_TEST][FAIL] Hard ignored a guaranteed Put Down in favor of an uncertain draw: %s" % str(action))
		quit(1)
		return
	print("[AI_HARD_COMPLETION_PROBABILITY_TEST][PASS]")
	quit(0)

func _card(suit: int, number: int) -> Dictionary:
	return {"suit": suit, "number": number, "point_value": 20 if number == 2 else (10 if number >= 10 else 5)}
