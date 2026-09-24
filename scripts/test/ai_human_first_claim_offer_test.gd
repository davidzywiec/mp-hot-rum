extends SceneTree

var latest_state: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	get_root().get_node("Game_State_Manager").game_state_updated.connect(_on_game_state_updated)
	var server: Node = load("res://scripts/network/ServerHandler.gd").new()
	get_root().add_child(server)
	server.game_manager = get_root().get_node("GameManager")
	server._ensure_turn_flow()
	server.set_ai_action_delay(60.0)
	server.register_player("Human", 11)
	var first_ai: int = int(server.register_add_ai_player(11, "Easy").get("peer_id", 0))
	var second_ai: int = int(server.register_add_ai_player(11, "Easy").get("peer_id", 0))
	var third_ai: int = int(server.register_add_ai_player(11, "Easy").get("peer_id", 0))
	server.start_game()
	if not _expect(int(latest_state.get("current_player_peer_id", 0)) == third_ai, "third AI starts the turn"):
		return
	for ai_peer_id in [third_ai, second_ai]:
		server.register_take_from_pile(ai_peer_id)
		var hand: Array = server.get_ai_observation(ai_peer_id).get("own_hand", [])
		server.register_discard_card(ai_peer_id, hand[0])
	if not _expect(int(latest_state.get("current_player_peer_id", 0)) == first_ai, "first AI begins the next turn"):
		return
	server.register_draw_from_deck(first_ai)
	if not _expect(bool(latest_state.get("claim_window_active", false)) and int(latest_state.get("claim_offer_peer_id", 0)) == 11, "human receives the first Claim Window offer"):
		return
	var premature: Dictionary = server.step_ai()
	if not _expect(not bool(premature.get("ok", true)) and int(latest_state.get("claim_offer_peer_id", 0)) == 11, "AI cannot preempt the human offer"):
		return
	server.register_pass_pile(11)
	if not _expect(int(latest_state.get("claim_offer_peer_id", 0)) == third_ai, "passing offers the card to the next AI"):
		return
	var ai_result: Dictionary = server.step_ai()
	if not _expect(bool(ai_result.get("ok", false)) and int(ai_result.get("actor_peer_id", 0)) == third_ai, "AI acts only after the human passes"):
		return
	print("[AI_HUMAN_FIRST_CLAIM_OFFER_TEST][PASS]")
	quit(0)

func _on_game_state_updated(state: Dictionary) -> void:
	latest_state = state

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_HUMAN_FIRST_CLAIM_OFFER_TEST][FAIL] %s" % description)
	quit(1)
	return false
