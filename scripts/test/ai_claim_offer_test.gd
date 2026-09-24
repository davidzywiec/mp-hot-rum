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
	var first_ai: int = int(server.register_add_ai_player(11, "Easy").get("peer_id", 0))
	var second_ai: int = int(server.register_add_ai_player(11, "Easy").get("peer_id", 0))
	server.start_game()
	if not _expect(game_manager.get_current_player_peer_id() == second_ai, "second-added AI is Current Player in this turn order"):
		return
	server.register_draw_from_deck(second_ai)
	if not _expect(game_manager.claim_window_active, "draw opens Claim Window"):
		return
	var result: Dictionary = server.step_ai()
	var action: Dictionary = result.get("action", {})
	if not _expect(bool(result.get("ok", false)) and int(result.get("actor_peer_id", 0)) == first_ai, "next AI in turn order acts on offer first"):
		return
	if not _expect(["claim_pile", "pass_claim"].has(str(action.get("type", ""))), "AI claims or passes through server Turn Flow"):
		return
	print("[AI_CLAIM_OFFER_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_CLAIM_OFFER_TEST][FAIL] %s" % description)
	quit(1)
	return false
