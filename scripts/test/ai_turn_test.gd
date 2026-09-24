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
	var ai_id: int = int(server.register_add_ai_player(11, "Easy").get("peer_id", 0))
	server.start_game()
	if not _expect(game_manager.get_current_player_peer_id() == ai_id, "AI starts as Current Player in this roster"):
		return
	var first: Dictionary = server.step_ai()
	if not _expect(bool(first.get("ok", false)) and game_manager.turn_pickup_completed, "AI completes a legal pickup through server action flow"):
		return
	if game_manager.claim_window_active:
		server.register_pass_pile(11)
	var second: Dictionary = server.step_ai()
	if not _expect(bool(second.get("ok", false)) and game_manager.get_current_player_peer_id() == 11, "AI legally discards and advances turn"):
		return
	print("[AI_TURN_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_TURN_TEST][FAIL] %s" % description)
	quit(1)
	return false
