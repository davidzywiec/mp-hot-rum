extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	ProjectSettings.set_setting("debug/network_logs", false)
	ProjectSettings.set_setting("debug/game_logs", false)
	var options: Dictionary = _parse_options(OS.get_cmdline_user_args())
	var server: Node = load("res://scripts/ai/AISimulationServer.gd").new()
	get_root().add_child(server)
	server.game_manager = get_root().get_node("GameManager")
	server._ensure_turn_flow()
	server.set_ai_simulation_budget(int(options.get("simulation_budget", 32)))
	var difficulties: Array = str(options.get("difficulties", "Medium,Hard")).split(",", false)
	var started: Dictionary = server.start_ai_simulation(difficulties, int(options.get("seed", 4242)), str(options.get("ruleset", "res://data/rulesets/default_ruleset.json")))
	if not bool(started.get("ok", false)):
		print(JSON.stringify({"status": "start_failed", "reason": started.get("reason", "unknown")}))
		quit(1)
		return
	var report: Dictionary = server.run_ai_simulation(int(options.get("max_actions", 5000)))
	print(JSON.stringify(report))
	quit(0 if str(report.get("status", "")) == "complete" else 1)

func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}
	for argument in arguments:
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if argument.begins_with("--") and parts.size() == 2:
			options[parts[0].replace("-", "_")] = parts[1]
	return options
