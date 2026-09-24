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
	game_manager.player_hands[ai_id] = [
		Card.new(Card.Suit.HEARTS, 5, 5),
		Card.new(Card.Suit.DIAMONDS, 5, 5),
		Card.new(Card.Suit.CLUBS, 5, 5),
		Card.new(Card.Suit.HEARTS, 7, 5),
		Card.new(Card.Suit.DIAMONDS, 7, 5),
		Card.new(Card.Suit.CLUBS, 7, 5),
		Card.new(Card.Suit.SPADES, 9, 5)
	]
	game_manager.mark_turn_pickup_completed()
	for _i in range(2):
		var result: Dictionary = server.step_ai()
		if not _expect(bool(result.get("ok", false)), "AI stages a legal required Set"):
			return
	if not _expect(game_manager.has_player_put_down(ai_id), "AI completes two-Set Put Down"):
		return
	if not _expect(game_manager.get_hand_size_for_peer(ai_id) == 1, "AI keeps only unmatched card in Hand"):
		return
	print("[AI_PUT_DOWN_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_PUT_DOWN_TEST][FAIL] %s" % description)
	quit(1)
	return false
