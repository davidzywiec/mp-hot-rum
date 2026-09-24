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
	game_manager.round_number = 5
	var hand: Array[Card] = []
	for number in [1, 3, 4, 6, 8, 10, 12, 13]:
		hand.append(Card.new(Card.Suit.SPADES, number, 5))
	for suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS]:
		hand.append(Card.new(suit, 5, 5))
	for number in range(6, 13):
		hand.append(Card.new(Card.Suit.HEARTS, number, 5))
	game_manager.player_hands[ai_id] = hand
	game_manager.mark_turn_pickup_completed()
	var observation: Dictionary = server.get_ai_observation(ai_id)
	if not _expect(not (observation.get("put_down_plan", []) as Array).is_empty(), "large Hand has a valid Set and seven-card Run plan"):
		return
	print("[AI_LARGE_HAND_PUT_DOWN_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_LARGE_HAND_PUT_DOWN_TEST][FAIL] %s" % description)
	quit(1)
	return false
