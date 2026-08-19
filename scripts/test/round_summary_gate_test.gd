extends SceneTree

var game_manager: Node = null

func _init() -> void:
	call_deferred("_run_and_quit")

func _run_and_quit() -> void:
	await process_frame
	await process_frame
	await process_frame
	var failed: bool = false
	game_manager = get_root().get_node_or_null("GameManager")
	if game_manager == null:
		printerr("[ROUND_SUMMARY_GATE_TEST][FAIL] GameManager autoload not found.")
		quit(1)
		return
	if not _run():
		failed = true
	quit(1 if failed else 0)

func _run() -> bool:
	_setup_round_state()

	var completion: Dictionary = game_manager.complete_current_round(2)
	if int(completion.get("completed_round", -1)) != 1:
		return _fail("Expected completed_round to be 1.")
	if game_manager.get("round_summary_pending") != true:
		return _fail("Expected round summary to remain pending after non-final round completion.")
	if int(game_manager.round_number) != 1:
		return _fail("Expected round_number to remain on completed round while summary is pending.")
	if _hand_size(1) != 0 or _hand_size(2) != 1:
		return _fail("Expected hands to remain unchanged until Next Round is requested.")

	var server_handler: Node = _build_server_handler()
	if server_handler == null:
		return _fail("Expected test to build a server handler.")
	server_handler.register_next_round(1)
	if game_manager.get("round_summary_pending") != true:
		return _fail("Expected round summary to remain pending until every player presses Next Round.")
	if int(game_manager.round_number) != 1:
		return _fail("Expected first Next Round vote not to advance the round.")
	if not game_manager.round_summary_continue_peer_ids.has(1):
		return _fail("Expected first Next Round vote to be visible in game state.")

	server_handler.register_next_round(2)
	if game_manager.get("round_summary_pending") == true:
		return _fail("Expected round summary pending state to clear after Next Round.")
	if int(game_manager.round_number) != 2:
		return _fail("Expected round_number to advance to 2 after Next Round.")
	if _hand_size(1) != 4 or _hand_size(2) != 4:
		return _fail("Expected next round cards to be dealt after Next Round.")

	print("[ROUND_SUMMARY_GATE_TEST][PASS]")
	return true

func _build_server_handler() -> Node:
	var server_handler_script: GDScript = load("res://scripts/network/ServerHandler.gd")
	if server_handler_script == null:
		return null
	var server_handler: Node = server_handler_script.new()
	get_root().add_child(server_handler)
	server_handler.set("players", game_manager.players)
	server_handler.set("game_manager", game_manager)
	server_handler.call("_ensure_turn_flow")
	return server_handler

func _setup_round_state() -> void:
	game_manager.end_game_session()
	game_manager.ruleset = _build_ruleset()
	game_manager.players.clear()
	game_manager.player_order.clear()
	game_manager.player_hands.clear()
	game_manager.score_sheet_data.clear()
	game_manager.latest_round_score_data.clear()
	game_manager.game_over = false
	game_manager.winning_peer_ids.clear()
	game_manager.round_number = 1
	game_manager.starting_player_index = 0
	game_manager.current_player_index = 0
	game_manager.current_player_peer_id = 1
	game_manager.deck = Deck.new(2)

	var player_one: Player = _build_player(1, "Player One")
	var player_two: Player = _build_player(2, "Player Two")
	game_manager.players[1] = player_one
	game_manager.players[2] = player_two
	game_manager.player_order.append(player_one)
	game_manager.player_order.append(player_two)
	game_manager.player_hands[1] = []
	game_manager.player_hands[2] = [Card.new(Card.Suit.HEARTS, 5, 5)]

func _build_ruleset() -> Ruleset:
	var ruleset: Ruleset = Ruleset.new()
	ruleset.max_rounds = 2
	ruleset.round_requirements = [_build_requirement(1, 3), _build_requirement(2, 4)]
	return ruleset

func _build_requirement(round_number: int, deal_count: int) -> RoundRequirement:
	var requirement: RoundRequirement = RoundRequirement.new()
	requirement.game_round = round_number
	requirement.deal_count = deal_count
	return requirement

func _build_player(peer_id: int, player_name: String) -> Player:
	var player: Player = Player.new()
	player.peer_id = peer_id
	player.name = player_name
	return player

func _hand_size(peer_id: int) -> int:
	if not game_manager.player_hands.has(peer_id):
		return -1
	var hand: Array = game_manager.player_hands[peer_id]
	return hand.size()

func _fail(message: String) -> bool:
	printerr("[ROUND_SUMMARY_GATE_TEST][FAIL] %s" % message)
	return false
