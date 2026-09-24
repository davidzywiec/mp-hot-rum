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
	var ai_result: Dictionary = server.register_add_ai_player(11, "Hard")
	var ai_id: int = int(ai_result.get("peer_id", 0))
	game_manager.player_hands[ai_id] = [Card.new(Card.Suit.HEARTS, 3, 5)]
	game_manager.player_hands[11] = [Card.new(Card.Suit.SPADES, 13, 1234)]
	game_manager.deck = Deck.new(2)
	game_manager.deck.clear()
	game_manager.deck.add_card_to_bottom(Card.new(Card.Suit.CLUBS, 12, 5678))
	var observation: Dictionary = server.get_ai_observation(ai_id)
	var own_hand: Array = observation.get("own_hand", [])
	if not _expect(own_hand.size() == 1 and int(own_hand[0].get("number", 0)) == 3, "AI receives own Hand"):
		return
	var serialized: String = JSON.stringify(observation)
	if not _expect(not serialized.contains("1234") and not serialized.contains("5678"), "AI cannot observe opponent Hand or Deck order"):
		return
	if not _expect(server.get_ai_observation(11).is_empty(), "human cannot request AI decision context"):
		return
	game_manager.discard_card_from_peer(11, Card.new(Card.Suit.SPADES, 13, 1234).to_dict())
	var history: Array = server.get_ai_observation(ai_id).get("public_card_history", [])
	if not _expect(history.size() == 1 and str(history[0].get("event", "")) == "discard", "AI may track public discard history"):
		return
	print("[AI_OBSERVATION_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_OBSERVATION_TEST][FAIL] %s" % description)
	quit(1)
	return false
