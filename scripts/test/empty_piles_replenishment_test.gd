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
	server.register_player("One", 11)
	server.register_player("Two", 12)
	server.start_game()
	game_manager.deck.clear()
	game_manager.discard_pile.clear()
	var current_peer_id: int = game_manager.get_current_player_peer_id()
	var hand_size_before: int = game_manager.get_hand_size_for_peer(current_peer_id)
	var result: Dictionary = server._ensure_turn_flow().apply_move(current_peer_id, {"type": "draw_from_deck"})
	if not _expect(bool(result.get("ok", false)), "pickup resumes when both piles are empty"):
		return
	if not _expect(game_manager.deck.size() == 102, "two fresh decks are added, one card seeds Discard, and one is drawn"):
		return
	if not _expect(game_manager.get_discard_top_card() != null, "first replenishment card seeds Discard"):
		return
	if not _expect(game_manager.get_hand_size_for_peer(current_peer_id) == hand_size_before + 1, "Current Player receives pickup card"):
		return
	if not _expect(game_manager.public_card_history[-1].get("event", "") == "replenish_discard", "new public Discard card is recorded"):
		return
	var discard_before: Dictionary = game_manager.serialize_discard_top()
	game_manager.deck.clear()
	game_manager.clear_claim_window()
	game_manager.reset_turn_pickup_completed()
	var next_result: Dictionary = server._ensure_turn_flow().apply_move(current_peer_id, {"type": "draw_from_deck"})
	if not _expect(bool(next_result.get("ok", false)) and game_manager.deck.size() == 103, "empty Deck replenishes even when Discard has a card"):
		return
	if not _expect(game_manager.serialize_discard_top() == discard_before, "replenishment preserves a nonempty Discard Pile"):
		return
	print("[EMPTY_PILES_REPLENISHMENT_TEST][PASS]")
	quit(0)

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[EMPTY_PILES_REPLENISHMENT_TEST][FAIL] %s" % description)
	quit(1)
	return false
