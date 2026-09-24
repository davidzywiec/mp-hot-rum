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
	server.set_ai_heuristic_weights({"opponent_risk": 3.0})
	var observation: Dictionary = server.get_ai_observation(ai_id)
	if not _expect(float((observation.get("heuristic_weights", {}) as Dictionary).get("opponent_risk", 0.0)) == 3.0, "server exposes configurable heuristic weights to AI"):
		return
	observation["own_hand"] = [
		{"suit": 0, "number": 9, "point_value": 5},
		{"suit": 1, "number": 10, "point_value": 5}
	]
	observation["round_requirement"] = {"sets_of_3": 0, "runs_of_4": 0, "runs_of_7": 0}
	observation["put_down_progress"] = {}
	observation["public_card_history"] = [{"event": "claim", "peer_id": 11, "card": {"suit": 2, "number": 9, "point_value": 5}}]
	var strategy: MediumAIStrategy = MediumAIStrategy.new()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	var safe_discard: Dictionary = strategy.choose_discard(observation, random)
	if not _expect(int(safe_discard.get("number", 0)) == 10, "Medium avoids discarding a rank publicly claimed by opponent"):
		return
	observation["heuristic_weights"] = {"opponent_risk": 0.0}
	var neutral_discard: Dictionary = strategy.choose_discard(observation, random)
	if not _expect(int(neutral_discard.get("number", 0)) == 9, "disabling opponent-risk weight changes the decision"):
		return
	print("[AI_MEDIUM_HISTORY_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_MEDIUM_HISTORY_TEST][FAIL] %s" % description)
	quit(1)
	return false
