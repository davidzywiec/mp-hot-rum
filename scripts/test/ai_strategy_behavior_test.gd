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
	server.set_ai_seed(12345)
	server.start_game()
	game_manager.player_hands[ai_id] = [
		Card.new(Card.Suit.HEARTS, 5, 5),
		Card.new(Card.Suit.DIAMONDS, 5, 5),
		Card.new(Card.Suit.SPADES, 8, 5)
	]
	game_manager.discard_pile.clear()
	game_manager.discard_pile.append(Card.new(Card.Suit.CLUBS, 5, 5))
	game_manager.reset_turn_pickup_completed()
	var medium_pickup: Dictionary = server.step_ai()
	if not _expect(str((medium_pickup.get("action", {}) as Dictionary).get("type", "")) == "take_from_pile", "Medium takes discard that completes a Set"):
		return
	print("[AI_STRATEGY_BEHAVIOR_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_STRATEGY_BEHAVIOR_TEST][FAIL] %s" % description)
	quit(1)
	return false
