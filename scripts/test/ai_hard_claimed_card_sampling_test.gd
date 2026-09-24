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
	if not _test_claimed_card_added_to_other_players_meld():
		return
	print("[AI_HARD_CLAIMED_CARD_SAMPLING_TEST][PASS]")
	quit(0)

func _test_claimed_card_added_to_other_players_meld() -> bool:
	var claimed_wild: Dictionary = _card(1, 2)
	var own_card: Dictionary = _card(0, 4)
	var meld_card_one: Dictionary = _card(0, 7)
	var meld_card_two: Dictionary = _card(2, 7)
	var history: Array = [
		{"event": "initial_discard", "card": claimed_wild},
		{"event": "claim", "card": claimed_wild, "peer_id": 22},
		{"event": "meld_play", "card": claimed_wild, "peer_id": 22}
	]
	for copy in range(2):
		for suit in range(4):
			for number in range(1, 14):
				var card: Dictionary = _card(suit, number)
				if card == claimed_wild or (copy == 0 and [own_card, meld_card_one, meld_card_two].has(card)):
					continue
				history.append({"event": "discard", "card": card, "peer_id": 33})
	var discard_top: Dictionary = history[-1].get("card", {})
	var observation: Dictionary = {
		"peer_id": 11,
		"current_player_peer_id": 11,
		"turn_pickup_completed": false,
		"own_hand": [own_card],
		"discard_top": discard_top,
		"deck_count": 1,
		"deck_copies": 2,
		"player_count": 3,
		"round_requirement": {"sets_of_3": 1},
		"has_put_down": true,
		"public_card_history": history,
		"public_melds": [{"owner_peer_id": 33, "cards_data": [meld_card_one, meld_card_two, claimed_wild]}],
		"simulation_budget": 32
	}
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 9
	var action: Dictionary = HardAIStrategy.new().choose_action(observation, random)
	if action.get("type", "") != "draw_from_deck":
		printerr("[AI_HARD_CLAIMED_CARD_SAMPLING_TEST][FAIL] Hard excluded a possible Deck copy after the claimed card was played on another player's Meld: %s" % str(action))
		quit(1)
		return false
	return true

func _card(suit: int, number: int) -> Dictionary:
	return {"suit": suit, "number": number, "point_value": 20 if number == 2 else (10 if number >= 10 else 5)}
