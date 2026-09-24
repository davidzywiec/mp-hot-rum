extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	ProjectSettings.set_setting("debug/network_logs", false)
	ProjectSettings.set_setting("debug/game_logs", false)
	var server: Node = load("res://scripts/network/ServerHandler.gd").new()
	get_root().add_child(server)
	server.game_manager = get_root().get_node("GameManager")
	server._ensure_turn_flow()
	var started: Dictionary = server.start_ai_simulation(["Medium", "Medium"], 4242, "res://data/rulesets/ai_simulation_test_ruleset.json")
	if not _expect(bool(started.get("ok", false)), "AI-only simulation starts without a human Host"):
		return
	var result: Dictionary = server.run_ai_simulation(1000)
	if not _expect(str(result.get("status", "")) == "complete" and bool(result.get("game_over", false)), "AI-only simulation reaches Game End"):
		printerr("[AI_SIMULATION_TEST] result=%s" % str(result))
		return
	if not _expect((result.get("winner_peer_ids", []) as Array).size() > 0, "simulation reports a winner"):
		return
	var game_manager: Node = server.game_manager
	server.queue_free()
	await process_frame
	game_manager.end_game_session()
	var invalid_server: Node = load("res://scripts/network/ServerHandler.gd").new()
	get_root().add_child(invalid_server)
	invalid_server.game_manager = game_manager
	invalid_server._ensure_turn_flow()
	var invalid: Dictionary = invalid_server.start_ai_simulation(["Easy", "Hard"], 4242, "res://data/rulesets/missing.json")
	if not _expect(not bool(invalid.get("ok", true)), "simulation rejects a missing Ruleset at entry"):
		return
	print("[AI_SIMULATION_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_SIMULATION_TEST][FAIL] %s" % description)
	quit(1)
	return false
