extends ServerHandler
class_name AISimulationServer

func is_simulation_mode() -> bool:
	return true

func start_ai_simulation(difficulties: Array, seed_value: int, ruleset_path: String = "res://data/rulesets/default_ruleset.json") -> Dictionary:
	if game_started or not players.is_empty():
		return {"ok": false, "reason": "Simulation needs a fresh server session"}
	if difficulties.size() < 2 or difficulties.size() > MAX_CONNECTIONS:
		return {"ok": false, "reason": "Simulation needs 2–6 AI Players"}
	for difficulty in difficulties:
		if not AI_PLAYER_DECISION_SCRIPT.is_valid_difficulty(str(difficulty)):
			return {"ok": false, "reason": "Invalid AI difficulty"}
	if not FileAccess.file_exists(ruleset_path):
		return {"ok": false, "reason": "Ruleset not found: %s" % ruleset_path}
	set_ai_seed(seed_value)
	for raw_difficulty in difficulties:
		_add_ai_player_to_roster(str(raw_difficulty))
	_refresh_roster()
	start_game(ruleset_path)
	if game_manager.ruleset == null:
		game_started = false
		players.clear()
		roster_order.clear()
		game_manager.end_game_session()
		return {"ok": false, "reason": "Could not load Ruleset: %s" % ruleset_path}
	return {"ok": true, "players": get_lobby_snapshot().get("players", [])}

func run_ai_simulation(max_actions: int = 10000) -> Dictionary:
	if not game_started:
		return {"status": "not_started", "game_over": false}
	var actions_taken: int = 0
	while not game_manager.game_over and actions_taken < max_actions:
		if game_manager.round_summary_pending:
			var previous_round: int = game_manager.round_number
			_advance_round_after_confirmations()
			if game_manager.round_summary_pending and game_manager.round_number == previous_round:
				return _simulation_report("stalled", actions_taken, "Round summary could not advance")
			continue
		if game_manager.claim_window_active and _ai_actor_peer_id() == -1:
			var expiry: Dictionary = _ensure_turn_flow().apply_move(-1, {"type": "expire_claim", "claim_window_id": game_manager.claim_window_id})
			if not bool(expiry.get("ok", false)):
				return _simulation_report("stalled", actions_taken, str(expiry.get("reason", "Claim Window could not close")))
			_apply_turn_flow_result(expiry)
			actions_taken += 1
			continue
		var result: Dictionary = step_ai()
		if not bool(result.get("ok", false)):
			var failure: Dictionary = _simulation_report("stalled", actions_taken, str(result.get("reason", "AI action failed")))
			failure["failed_action"] = result.get("action", {})
			failure["actor_peer_id"] = result.get("actor_peer_id", -1)
			return failure
		actions_taken += 1
	if game_manager.game_over:
		game_started = false
		return _simulation_report("complete", actions_taken, "")
	return _simulation_report("action_limit", actions_taken, "Simulation action limit reached")

func _simulation_report(status: String, actions_taken: int, reason: String) -> Dictionary:
	return {
		"status": status,
		"game_over": game_manager != null and game_manager.game_over,
		"actions_taken": actions_taken,
		"round_number": game_manager.round_number if game_manager != null else 0,
		"current_player_peer_id": game_manager.get_current_player_peer_id() if game_manager != null else -1,
		"turn_pickup_completed": game_manager.turn_pickup_completed if game_manager != null else false,
		"claim_window_active": game_manager.claim_window_active if game_manager != null else false,
		"deck_count": game_manager.deck.size() if game_manager != null and game_manager.deck != null else 0,
		"discard_top": game_manager.serialize_discard_top() if game_manager != null else {},
		"winner_peer_ids": game_manager.get_winning_peer_ids() if game_manager != null else [],
		"score_sheet": game_manager.get_score_sheet_data() if game_manager != null else [],
		"reason": reason
	}
