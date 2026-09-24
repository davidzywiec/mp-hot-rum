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
	server.register_add_ai_player(11, "Easy")
	server.set_ai_action_delay(0.01)
	server.start_game()
	await create_timer(0.25).timeout
	var ai_acted: bool = game_manager.claim_window_active or game_manager.get_current_player_peer_id() == 11 or game_manager.round_summary_pending
	if not ai_acted:
		printerr("[AI_AUTOMATIC_TURN_TEST][FAIL] AI did not automatically take its turn.")
		quit(1)
		return
	print("[AI_AUTOMATIC_TURN_TEST][PASS]")
	quit(0)
