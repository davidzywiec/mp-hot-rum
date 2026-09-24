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
	game_manager.round_number = 5
	game_manager.player_hands[ai_id] = [
		Card.new(Card.Suit.HEARTS, 4, 5),
		Card.new(Card.Suit.DIAMONDS, 4, 5),
		Card.new(Card.Suit.CLUBS, 4, 5),
		Card.new(Card.Suit.SPADES, 4, 5),
		Card.new(Card.Suit.HEARTS, 6, 5),
		Card.new(Card.Suit.HEARTS, 7, 5),
		Card.new(Card.Suit.HEARTS, 8, 5)
	]
	game_manager.mark_turn_pickup_completed()
	var result: Dictionary = server.step_ai()
	if not _expect(bool(result.get("ok", false)), "AI discards"):
		return
	var action: Dictionary = result.get("action", {})
	var card: Dictionary = action.get("card_data", {})
	if not _expect(int(card.get("number", -1)) == 4, "AI drops surplus Set card and preserves Run progress"):
		return
	print("[AI_RUN_PRIORITY_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_RUN_PRIORITY_TEST][FAIL] %s" % description)
	quit(1)
	return false
