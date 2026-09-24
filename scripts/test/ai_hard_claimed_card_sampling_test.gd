extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var claimed: Dictionary = _card(1, 2)
	var discard_top: Dictionary = _card(0, 3)
	var own_card: Dictionary = _card(0, 4)
	var unknown_deck_card: Dictionary = _card(2, 13)
	var history: Array = [
		{"event": "initial_discard", "card": claimed},
		{"event": "claim", "card": claimed, "peer_id": 22}
	]
	for suit in range(4):
		for number in range(1, 14):
			var card: Dictionary = _card(suit, number)
			if [claimed, discard_top, own_card, unknown_deck_card].has(card):
				continue
			history.append({"event": "discard", "card": card, "peer_id": 22})
	history.append({"event": "discard", "card": discard_top, "peer_id": 22})
	var observation: Dictionary = {
		"peer_id": 11,
		"current_player_peer_id": 11,
		"turn_pickup_completed": false,
		"own_hand": [own_card],
		"discard_top": discard_top,
		"deck_count": 1,
		"deck_copies": 1,
		"player_count": 2,
		"round_requirement": {"runs_of_4": 1},
		"public_card_history": history,
		"public_melds": [],
		"simulation_budget": 256
	}
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	var action: Dictionary = HardAIStrategy.new().choose_action(observation, random)
	if action.get("type", "") != "take_from_pile":
		printerr("[AI_HARD_CLAIMED_CARD_SAMPLING_TEST][FAIL] Hard sampled a known opponent-held card as a future draw: %s" % str(action))
		quit(1)
		return
	print("[AI_HARD_CLAIMED_CARD_SAMPLING_TEST][PASS]")
	quit(0)

func _card(suit: int, number: int) -> Dictionary:
	return {"suit": suit, "number": number, "point_value": 20 if number == 2 else (10 if number >= 10 else 5)}
