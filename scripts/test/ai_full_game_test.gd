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
	var started: Dictionary = server.start_ai_simulation(["Medium", "Hard"], 4242)
	if not bool(started.get("ok", false)):
		printerr("[AI_FULL_GAME_TEST][FAIL] Could not start: %s" % str(started))
		quit(1)
		return
	var report: Dictionary = server.run_ai_simulation(5000)
	if str(report.get("status", "")) != "complete" or int(report.get("round_number", 0)) != 8:
		printerr("[AI_FULL_GAME_TEST][FAIL] %s" % str(report))
		quit(1)
		return
	print("[AI_FULL_GAME_TEST][PASS] actions=%d winner_ids=%s" % [int(report.get("actions_taken", 0)), str(report.get("winner_peer_ids", []))])
	quit(0)
