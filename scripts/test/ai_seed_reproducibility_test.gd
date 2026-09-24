extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	ProjectSettings.set_setting("debug/network_logs", false)
	ProjectSettings.set_setting("debug/game_logs", false)
	var first: Dictionary = await _simulate_once(7654)
	var second: Dictionary = await _simulate_once(7654)
	if str(first.get("status", "")) != "complete" or str(second.get("status", "")) != "complete":
		printerr("[AI_SEED_REPRODUCIBILITY_TEST][FAIL] both runs must complete: %s / %s" % [str(first), str(second)])
		quit(1)
		return
	for key in ["actions_taken", "winner_peer_ids", "score_sheet"]:
		if first.get(key) != second.get(key):
			printerr("[AI_SEED_REPRODUCIBILITY_TEST][FAIL] %s differs" % key)
			quit(1)
			return
	print("[AI_SEED_REPRODUCIBILITY_TEST][PASS]")
	quit(0)

func _simulate_once(seed_value: int) -> Dictionary:
	var game_manager: Node = get_root().get_node("GameManager")
	game_manager.end_game_session()
	var server: Node = load("res://scripts/ai/AISimulationServer.gd").new()
	get_root().add_child(server)
	server.game_manager = game_manager
	server._ensure_turn_flow()
	var started: Dictionary = server.start_ai_simulation(["Easy", "Medium", "Hard"], seed_value, "res://data/rulesets/ai_simulation_test_ruleset.json")
	var report: Dictionary = server.run_ai_simulation(3000) if bool(started.get("ok", false)) else {"status": "start_failed"}
	server.queue_free()
	await process_frame
	return report
