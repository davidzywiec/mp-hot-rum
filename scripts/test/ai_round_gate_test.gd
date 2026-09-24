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
	var ruleset: Ruleset = Ruleset.new()
	ruleset.max_rounds = 2
	for round_number in [1, 2]:
		var requirement: RoundRequirement = RoundRequirement.new()
		requirement.game_round = round_number
		requirement.deal_count = 3
		ruleset.round_requirements.append(requirement)
	game_manager.ruleset = ruleset
	game_manager.round_number = 1
	game_manager.deck = Deck.new(2)
	game_manager.player_hands[11] = [Card.new(Card.Suit.HEARTS, 8, 5)]
	game_manager.player_hands[ai_id] = []
	game_manager.complete_current_round(ai_id)
	if not _expect(game_manager.round_summary_pending, "Round summary is pending"):
		return
	server.register_next_round(11)
	if not _expect(not game_manager.round_summary_pending and game_manager.round_number == 2, "one human confirmation advances with AI auto-confirmed"):
		return
	print("[AI_ROUND_GATE_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_ROUND_GATE_TEST][FAIL] %s" % description)
	quit(1)
	return false
