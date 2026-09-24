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
	var ai_id: int = int(server.register_add_ai_player(11, "Hard").get("peer_id", 0))
	server.set_ai_seed(712)
	server.set_ai_simulation_budget(24)
	server.start_game()
	var observation: Dictionary = server.get_ai_observation(ai_id)
	if not _expect(int(observation.get("simulation_budget", 0)) == 24, "Hard search budget is configurable"):
		return
	var result: Dictionary = server.step_ai()
	if not _expect(bool(result.get("ok", false)) and ["draw_from_deck", "take_from_pile"].has(str((result.get("action", {}) as Dictionary).get("type", ""))), "Hard chooses a legal pickup"):
		return
	print("[AI_HARD_STRATEGY_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_HARD_STRATEGY_TEST][FAIL] %s" % description)
	quit(1)
	return false
