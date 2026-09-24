extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var strategy: HardAIStrategy = HardAIStrategy.new()
	var observation: Dictionary = {
		"player_count": 2,
		"own_hand": [],
		"discard_top": {"suit": 0, "number": 8, "point_value": 5},
		"public_melds": [],
		"public_card_history": [
			{"event": "initial_discard", "card": {"suit": 0, "number": 7, "point_value": 5}},
			{"event": "discard", "card": {"suit": 0, "number": 8, "point_value": 5}}
		]
	}
	var unseen: Array = strategy._unseen_cards(observation)
	if not _expect(unseen.size() == 50, "Hard excludes both visible Discard cards from draw samples"):
		return
	observation["deck_copies"] = 3
	if not _expect(strategy._unseen_cards(observation).size() == 154, "Hard sampling pool accounts for replenished decks"):
		return
	print("[AI_HARD_VISIBLE_CARDS_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_HARD_VISIBLE_CARDS_TEST][FAIL] %s" % description)
	quit(1)
	return false
