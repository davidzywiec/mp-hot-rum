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
	game_manager.game_over = true
	server.register_play_again_vote(11)
	await create_timer(0.5).timeout
	if not _expect(not game_manager.game_over and server.game_started, "one human Play Again vote restarts mixed Game"):
		return
	if not _expect((server.players[ai_id] as Player).ready, "AI automatically rejoins ready"):
		return
	if not _expect(not (server.players[11] as Player).ready, "human readiness resets after Play Again"):
		return
	print("[AI_PLAY_AGAIN_VOTE_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_PLAY_AGAIN_VOTE_TEST][FAIL] %s" % description)
	quit(1)
	return false
