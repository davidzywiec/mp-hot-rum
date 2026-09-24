extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var game_manager: Node = get_root().get_node("GameManager")
	game_manager.end_game_session()
	var server: Node = load("res://scripts/network/ServerHandler.gd").new()
	get_root().add_child(server)
	server.game_manager = game_manager
	server._ensure_turn_flow()
	server.register_player("Human", 11)
	var ai_id: int = int(server.register_add_ai_player(11, "Medium").get("peer_id", 0))
	server.start_game()
	game_manager.player_hands[ai_id] = [Card.new(Card.Suit.SPADES, 5, 5)]
	game_manager.mark_turn_pickup_completed()
	game_manager.set_player_put_down(ai_id, true)
	game_manager.player_committed_melds[ai_id] = [{
		"meld_id": 1,
		"owner_peer_id": ai_id,
		"group_type": "set3",
		"set_number": 5,
		"run_suit": -1,
		"cards_data": [
			Card.new(Card.Suit.HEARTS, 5, 5).to_dict(),
			Card.new(Card.Suit.DIAMONDS, 5, 5).to_dict(),
			Card.new(Card.Suit.CLUBS, 5, 5).to_dict()
		]
	}]
	var result: Dictionary = server.step_ai()
	var melds: Array = game_manager.serialize_public_melds()
	if not _expect(bool(result.get("ok", false)) and (melds[0].get("cards_data", []) as Array).size() == 4, "AI adds its legal card to public Meld"):
		return
	print("[AI_ADD_TO_MELD_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_ADD_TO_MELD_TEST][FAIL] %s" % description)
	quit(1)
	return false
