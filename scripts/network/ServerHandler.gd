# ServerHandler.gd
# Implements server-specific networking behavior

extends Node
class_name ServerHandler

const PORT: int = 7000
const MAX_CONNECTIONS: int = 6
const NETWORK_LOG_SETTING_PATH: String = "debug/network_logs"
const SNAPSHOT_LOG_SETTING_PATH: String = "debug/snapshot_logs"
const DEBUG_UI_SETTING_PATH: String = "debug/ui_debug"
const TURN_DEBUG: bool = true
const CLAIM_WINDOW_SECONDS: int = 30
const PLAY_AGAIN_RESTART_DELAY_SECONDS: float = 0.35
const RETURN_TO_MENU_SCENE_PATH: String = "res://scenes/menu/main_menu.tscn"
const TURN_FLOW_SCRIPT: GDScript = preload("res://scripts/game/classes/TurnFlow.gd")

# Timestamped logging for server output.
func _ts() -> String:
	return Time.get_datetime_string_from_system()

func _log(msg: String) -> void:
	if not ProjectSettings.get_setting(NETWORK_LOG_SETTING_PATH, true):
		return
	print("[%s] %s" % [_ts(), msg])

func _log_err(msg: String) -> void:
	if not ProjectSettings.get_setting(NETWORK_LOG_SETTING_PATH, true):
		return
	printerr("[%s] %s" % [_ts(), msg])

# Player registry and ready-tracking
var players: Dictionary = {} # key: player_name, value: Player
var ready_players: Dictionary = {}
var game_manager: Node = null
var turn_flow: RefCounted = null
var play_again_votes: Dictionary = {} # key: peer_id, value: true
var play_again_restart_pending: bool = false

# TODO: point this at your actual game scene when its added
const GAME_SCENE_PATH: String = "res://scenes/game/MainGame.tscn"

# Initializes the server and sets it as the active multiplayer peer
func start():
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

	# Attempt to bind server on the given port with max allowed clients
	var error: int = peer.create_server(PORT, MAX_CONNECTIONS)

	# Check if there was an error during setup
	if error != OK:
		_log_err("Failed to start server. Error code: %s" % str(error))
		return

	# Set this peer as the multiplayer authority
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_bind_game_manager()

	_log("Server successfully started on port %d" % PORT)
	_log("Connecting register_username signal to Network_Manager.register_player")
	#SignalManager.register_username.connect(Network_Manager.register_player)

func _bind_game_manager() -> void:
	if game_manager != null:
		_ensure_turn_flow()
		return
	if not get_node_or_null("/root/GameManager"):
		_log_err("GameManager autoload not found; cannot bind server game state.")
		return
	game_manager = get_node("/root/GameManager")
	_ensure_turn_flow()

func _ensure_turn_flow() -> RefCounted:
	if turn_flow == null:
		turn_flow = TURN_FLOW_SCRIPT.new()
	if game_manager != null:
		turn_flow.configure(game_manager, players)
	return turn_flow

# Called when a new player connects to the server
func _on_peer_connected(peer_id: int) -> void:
	_log("Player connected with peer ID: %s" % str(peer_id))
	# Defer actual registration until username is received

# Called externally when the client sends their username
func register_player(new_player_info: String, peer_id: int) -> void:
	_log("Server registering: %s" % new_player_info)

	if not players.has(peer_id):
		var player: Player = Player.new()
		player.peer_id = peer_id
		player.name = new_player_info
		players[peer_id] = player

		_log("%s has joined the game!" % new_player_info)
		SignalManager.player_connected.emit(new_player_info)
		if game_manager != null:
			game_manager.load_players(players)
		_broadcast_player_state()
		_broadcast_game_state()
		_broadcast_host_if_changed()

# Called externally when the client marks themselves ready
func register_ready_flag(peer_id: int, ready_flag: bool) -> void:
	if players.has(peer_id):
		players[peer_id].ready = ready_flag
		ready_players[peer_id] = ready_flag

		_log("%s is ready." % players[peer_id].name)
		SignalManager.player_ready.emit(peer_id)
		_broadcast_player_state()
		_broadcast_game_state()

func register_play_again_vote(peer_id: int, wants_play_again: bool = true) -> void:
	if not _ensure_game_manager_bound():
		return
	if not players.has(peer_id):
		_log_err("Ignoring play-again vote from unknown peer %s." % str(peer_id))
		return
	if not game_manager.game_over:
		_log("Ignoring play-again vote from %s: game is not over." % str(peer_id))
		return
	if wants_play_again:
		play_again_votes[peer_id] = true
	else:
		play_again_votes.erase(peer_id)
	_log("Peer %s play-again vote: %s" % [str(peer_id), str(wants_play_again)])
	if int(players.size()) < 2 and wants_play_again:
		_return_to_lobby_with_connected_players("Play-again requested with only one connected player.")
		return
	if _all_connected_players_voted_play_again():
		_schedule_play_again_restart_validation()
		return
	_broadcast_game_state()

func register_debug_end_game(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	if not players.has(peer_id):
		_log_err("Ignoring debug end-game request from unknown peer %s." % str(peer_id))
		return
	if not _debug_ui_enabled():
		_log("Ignoring debug end-game request from %s: debug/ui_debug is disabled." % str(peer_id))
		return
	if game_manager.game_over:
		_log("Ignoring debug end-game request from %s: game is already over." % str(peer_id))
		return
	var completion: Dictionary = game_manager.force_end_game(peer_id, true)
	var winner_ids: Array = completion.get("winner_peer_ids", [])
	var winner_names: String = _winner_names_text(winner_ids)
	_log("Debug end-game requested by peer %s. Winner(s): %s" % [str(peer_id), winner_names])
	Game_State_Manager.send_round_update(game_manager.round_number, "Game Over: %s" % winner_names)
	_broadcast_game_state()

func register_end_turn(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	if TURN_DEBUG:
		_log("[TURN_DEBUG][SERVER][register_end_turn] sender=%s current_turn_peer=%s current_idx=%d order_size=%d" % [
			str(peer_id),
			str(game_manager.get_current_player_peer_id()),
			int(game_manager.current_player_index),
			int(game_manager.player_order.size())
		])
	var result: Dictionary = _ensure_turn_flow().apply_move(peer_id, {
		"type": "end_turn"
	})
	_apply_turn_flow_result(result)

func register_draw_from_deck(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	var result: Dictionary = _ensure_turn_flow().apply_move(peer_id, {
		"type": "draw_from_deck",
		"claim_window_seconds": CLAIM_WINDOW_SECONDS
	})
	_apply_turn_flow_result(result)

func register_put_down(peer_id: int, cards_data: Array) -> void:
	if not _ensure_game_manager_bound():
		return
	var gate_result: Dictionary = _ensure_turn_flow().apply_move(peer_id, {
		"type": "put_down_gate"
	})
	if not bool(gate_result.get("ok", false)):
		_reject_put_down(peer_id, str(gate_result.get("reason", "Cannot put down right now.")))
		return
	if game_manager.has_player_put_down(peer_id):
		_reject_put_down(peer_id, "You already completed put down for this round.")
		return
	if cards_data.is_empty():
		_reject_put_down(peer_id, "Select cards first.")
		return

	var full_hand: Array[Card] = game_manager.get_hand_cards_for_peer(peer_id)
	if full_hand.is_empty():
		_reject_put_down(peer_id, "No cards available in hand.")
		return

	var staged_cards_data: Array = game_manager.get_put_down_buffer_for_peer(peer_id)
	var full_hand_counts: Dictionary = _build_signature_counts_from_cards(full_hand)
	var staged_cards: Array[Card] = []
	var staged_counts: Dictionary = _build_signature_counts_from_dicts(staged_cards_data, staged_cards)
	if staged_counts.is_empty() and staged_cards_data.size() > 0:
		_reject_put_down(peer_id, "Your staged meld state is invalid. Try again.")
		return
	if staged_cards.size() != staged_cards_data.size():
		_reject_put_down(peer_id, "Your staged meld state is invalid. Try again.")
		return
	var available_counts: Dictionary = _subtract_signature_counts(full_hand_counts, staged_counts)
	if available_counts.is_empty() and full_hand_counts.size() > 0 and staged_counts.size() > 0:
		_reject_put_down(peer_id, "Your staged meld state is invalid. Try again.")
		return

	var selected_cards: Array[Card] = []
	var selected_counts: Dictionary = _build_signature_counts_from_dicts(cards_data, selected_cards)
	if selected_counts.is_empty() and cards_data.size() > 0:
		_reject_put_down(peer_id, "Invalid card selection payload.")
		return
	if not _signature_counts_subset(selected_counts, available_counts):
		_reject_put_down(peer_id, "Selected cards are already used in a filled slot or not in hand.")
		return

	var requirement: RoundRequirement = game_manager.get_current_round_requirement()
	var progress: Dictionary = game_manager.get_put_down_progress_for_peer(peer_id)
	var validation: Dictionary = PutDownValidator.validate_single_group(selected_cards, requirement, progress)
	if not bool(validation.get("ok", false)):
		_reject_put_down(peer_id, str(validation.get("reason", "Invalid meld for this round.")))
		return

	var group_type: String = str(validation.get("group_type", ""))
	var set_number: int = int(validation.get("set_number", -1))
	var run_suit: int = int(validation.get("run_suit", -1))
	game_manager.append_put_down_buffer_for_peer(peer_id, cards_data)
	game_manager.append_put_down_group_buffer_for_peer(peer_id, group_type, set_number, run_suit, cards_data)
	game_manager.record_put_down_group(peer_id, group_type, set_number, run_suit)
	var put_down_complete: bool = game_manager.staged_put_down_is_complete_for_peer(peer_id)
	game_manager.set_player_put_down(peer_id, false)

	if put_down_complete:
		var all_staged_cards_data: Array = game_manager.get_put_down_buffer_for_peer(peer_id)
		var removed_cards: Array[Card] = game_manager.remove_cards_from_peer_hand(peer_id, all_staged_cards_data)
		if removed_cards.size() != all_staged_cards_data.size():
			_reject_put_down(peer_id, "Could not finalize put down from staged melds.")
			game_manager.reset_put_down_progress_for_peer(peer_id)
			_send_private_put_down_buffer_to_peer(peer_id)
			_broadcast_game_state()
			return
		var committed_meld_count: int = game_manager.commit_staged_put_down_groups_for_peer(peer_id)
		if committed_meld_count <= 0:
			_reject_put_down(peer_id, "Could not finalize meld slots.")
			game_manager.reset_put_down_progress_for_peer(peer_id)
			_send_private_put_down_buffer_to_peer(peer_id)
			_broadcast_game_state()
			return
		game_manager.clear_put_down_buffer_for_peer(peer_id)
		game_manager.set_player_put_down(peer_id, true)
		_send_private_hand_to_peer(peer_id)

		var remaining_cards: int = game_manager.get_hand_size_for_peer(peer_id)
		if remaining_cards <= 0:
			_handle_round_finished(peer_id, "Peer %s put down their final cards. Round is over." % str(peer_id))
			return

	var staged_size: int = game_manager.get_put_down_buffer_size_for_peer(peer_id)
	_send_private_put_down_buffer_to_peer(peer_id)
	_log("Applied put-down slot for peer %s with %d cards. complete=%s staged_cards=%d" % [
		str(peer_id), selected_cards.size(), str(put_down_complete), staged_size
	])
	_broadcast_game_state()

func register_add_to_meld(peer_id: int, meld_id: int, card_data: Dictionary) -> void:
	if not _ensure_game_manager_bound():
		return
	var gate_result: Dictionary = _ensure_turn_flow().apply_move(peer_id, {
		"type": "add_to_meld_gate"
	})
	if not bool(gate_result.get("ok", false)):
		_reject_put_down(peer_id, str(gate_result.get("reason", "Cannot add to melds right now.")))
		return
	if not game_manager.has_player_put_down(peer_id):
		_reject_put_down(peer_id, "You must go down before adding to melds.")
		return
	if card_data.is_empty():
		_reject_put_down(peer_id, "Select a card to add.")
		return

	var target_meld: Dictionary = game_manager.get_committed_meld_by_id(meld_id)
	if target_meld.is_empty():
		_reject_put_down(peer_id, "Target meld no longer exists.")
		return

	var hand_cards: Array[Card] = game_manager.get_hand_cards_for_peer(peer_id)
	if hand_cards.is_empty():
		_reject_put_down(peer_id, "No cards available in hand.")
		return
	var hand_counts: Dictionary = _build_signature_counts_from_cards(hand_cards)
	var selected_cards: Array[Card] = []
	var selected_counts: Dictionary = _build_signature_counts_from_dicts([card_data], selected_cards)
	if selected_counts.is_empty():
		_reject_put_down(peer_id, "Invalid selected card.")
		return
	if not _signature_counts_subset(selected_counts, hand_counts):
		_reject_put_down(peer_id, "Selected card is not in your hand.")
		return
	var add_card: Card = selected_cards[0]
	var add_validation: Dictionary = _validate_card_for_meld_add(target_meld, add_card)
	if not bool(add_validation.get("ok", false)):
		_reject_put_down(peer_id, str(add_validation.get("reason", "Card does not fit this meld.")))
		return

	var removed_cards: Array[Card] = game_manager.remove_cards_from_peer_hand(peer_id, [card_data])
	if removed_cards.size() != 1:
		_reject_put_down(peer_id, "Could not remove card from hand.")
		return
	var removed_card: Card = removed_cards[0]
	if removed_card == null:
		_reject_put_down(peer_id, "Could not remove card from hand.")
		return
	var applied: bool = game_manager.add_card_to_committed_meld(meld_id, removed_card.to_dict())
	if not applied:
		_reject_put_down(peer_id, "Could not apply card to meld.")
		return

	_send_private_hand_to_peer(peer_id)

	var remaining_cards: int = game_manager.get_hand_size_for_peer(peer_id)
	if remaining_cards <= 0:
		_handle_round_finished(peer_id, "Peer %s played their final card by adding to meld %d. Round is over." % [str(peer_id), meld_id])
		return

	_log("Peer %s added a card to meld %d." % [str(peer_id), meld_id])
	_broadcast_game_state()

func register_discard_card(peer_id: int, card_data: Dictionary) -> void:
	if not _ensure_game_manager_bound():
		return
	var result: Dictionary = _ensure_turn_flow().apply_move(peer_id, {
		"type": "discard_card",
		"card_data": card_data
	})
	_apply_turn_flow_result(result)

func register_take_from_pile(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	var result: Dictionary = _ensure_turn_flow().apply_move(peer_id, {
		"type": "take_from_pile"
	})
	_apply_turn_flow_result(result)

func register_pass_pile(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	var result: Dictionary = _ensure_turn_flow().apply_move(peer_id, {
		"type": "pass_claim"
	})
	_apply_turn_flow_result(result)

func register_claim_pile(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	var result: Dictionary = _ensure_turn_flow().apply_move(peer_id, {
		"type": "claim_pile"
	})
	_apply_turn_flow_result(result)

# Called when a player disconnects
func _on_peer_disconnected(peer_id: int) -> void:
	_log("Peer %d disconnected." % peer_id)
	# Optional: implement disconnection cleanup if you store peer_id -> name mapping
	players.erase(peer_id)
	ready_players.erase(peer_id)
	play_again_votes.erase(peer_id)
	if game_manager != null:
		game_manager.load_players(players)
	if players.is_empty():
		_end_game_session("All players left the match.")
		return
	if game_manager != null and game_manager.game_over and int(players.size()) < 2:
		_return_to_lobby_with_connected_players("Only one player remains after disconnect.")
		return
	if game_manager != null and game_manager.game_over and _all_connected_players_voted_play_again():
		_schedule_play_again_restart_validation()
		return
	_broadcast_player_state()
	_broadcast_game_state()
	_broadcast_host_if_changed()

func _current_host_peer_id() -> int:
	# First player == lowest connected peer_id
	var ids: Array = []
	# Prefer authoritative list; use the registries you maintain
	for pid in players.keys():
		ids.append(pid)
	ids.sort()
	if ids.size() > 0:
		return ids[0]
	else:
		return -1

func _broadcast_host_if_changed() -> void:
	var host: int = _current_host_peer_id()
	if host == -1:
		return
	Game_State_Manager.send_host(host)

# Sync player state to all connected clients
func _broadcast_player_state() -> void:
	# Check for valid peer setup
	if multiplayer.multiplayer_peer == null:
		_log_err("Cannot broadcast: multiplayer peer is null.")
		return

	# No players to broadcast? Warn and skip.
	if players.is_empty():
		_log("Warning: No players to broadcast.")
		return

	var state_array: Array = []
	for p in players.values():
		state_array.append(p.to_public_dict())

	# Optional: preview the data being sent
	_log("Broadcasting player state to clients: %s" % str(state_array))
	Game_State_Manager.send_player_state(state_array)

func _broadcast_game_state() -> void:
	if game_manager == null:
		return
	if ProjectSettings.get_setting(SNAPSHOT_LOG_SETTING_PATH, false):
		_log("Broadcasting game snapshot to clients.")
	var state_players: Array = []
	for p in game_manager.players.values():
		state_players.append(p.to_public_dict())
	var order_ids: Array = []
	if game_manager.player_order.size() > 0:
		for p in game_manager.player_order:
			if p is Player:
				order_ids.append(p.peer_id)
			elif typeof(p) == TYPE_DICTIONARY and p.has("peer_id"):
				order_ids.append(p["peer_id"])
	var claim_eligible_peer_ids: Array = turn_flow.eligible_claim_peer_ids()
	game_manager.claim_eligible_peer_ids = claim_eligible_peer_ids.duplicate()
	var claim_passed_peer_ids: Array = turn_flow.passed_claim_peer_ids()
	game_manager.claim_passed_peer_ids = claim_passed_peer_ids.duplicate()
	var snapshot: Dictionary = {
		"players": state_players,
		"player_order_ids": order_ids,
		"round_number": game_manager.round_number,
		"current_player_index": game_manager.current_player_index,
		"current_player_peer_id": game_manager.get_current_player_peer_id(),
		"starting_player_index": game_manager.starting_player_index,
		"discard_top": game_manager.serialize_discard_top(),
		"claim_window_active": game_manager.claim_window_active,
		"claim_deadline_unix": game_manager.claim_deadline_unix,
		"claim_opened_by_peer_id": game_manager.claim_opened_by_peer_id,
		"claim_eligible_peer_ids": claim_eligible_peer_ids,
		"claim_passed_peer_ids": claim_passed_peer_ids,
		"claim_status_rows": game_manager.claim_status_rows.duplicate(true),
		"turn_pickup_completed": game_manager.turn_pickup_completed,
		"turn_discard_completed": game_manager.turn_discard_completed,
		"put_down_player_ids": game_manager.get_put_down_player_ids(),
		"put_down_progress": game_manager.get_put_down_progress_snapshot(),
		"public_melds": game_manager.serialize_public_melds(),
		"round_requirement": game_manager.serialize_current_round_requirement(),
		"score_sheet": game_manager.get_score_sheet_data(),
		"latest_round_score": game_manager.get_latest_round_score_data(),
		"game_over": game_manager.game_over,
		"winner_peer_ids": game_manager.get_winning_peer_ids(),
		"play_again_peer_ids": _play_again_vote_peer_ids()
	}
	if TURN_DEBUG:
		_log("[TURN_DEBUG][SERVER][snapshot] round=%d current_idx=%d current_peer=%s order_ids=%s" % [
			int(snapshot["round_number"]),
			int(snapshot["current_player_index"]),
			str(snapshot["current_player_peer_id"]),
			str(order_ids)
		])
	if ProjectSettings.get_setting(SNAPSHOT_LOG_SETTING_PATH, false):
		_log("Snapshot: %s" % str(snapshot))
	Game_State_Manager.send_game_state(snapshot)

# Sync Countdown to start game (SERVER-AUTHORITATIVE)
func _toggle_countdown(flag: bool, sec: float = 10.0) -> void:
	if flag:
		var args: PackedStringArray = OS.get_cmdline_args()
		if ProjectSettings.get_setting("debug/short_countdown", false) or args.has("--short-countdown"):
			sec = 1.0
		_log("Server starting countdown to start game! seconds=%s short_setting=%s args=%s" % [
			str(sec),
			str(ProjectSettings.get_setting("debug/short_countdown", false)),
			str(args)
		])
		var seconds: float = sec
		var end_unix: int = int(Time.get_unix_time_from_system() + seconds)
		# Broadcast exact end time to every client
		Game_State_Manager.send_countdown(end_unix)
		# Schedule the scene change on the server
		var t: SceneTreeTimer = get_tree().create_timer(float(seconds), false)
		t.timeout.connect(func ():
			_log("Countdown finished - ordering scene change")
			start_game()
			Game_State_Manager.send_change_scene(GAME_SCENE_PATH)
			# Re-broadcast shortly after scene change to catch late client binds.
			var rebroadcast_timer: SceneTreeTimer = get_tree().create_timer(0.35, false)
			rebroadcast_timer.timeout.connect(func ():
				_broadcast_game_state()
			)
		)
	else:
		_log("Server stopping countdown to start game!")
		# Optional: if you add a 'cancel' path, you can broadcast a stop here
		Game_State_Manager.send_toggle_countdown(false)

# Start the game with the current default rule set
func start_game() -> void:
	if game_manager == null:
		_log_err("GameManager not initialized; cannot start game.")
		return
	play_again_votes.clear()
	_log("Server loading players into game.")
	game_manager.load_players(players)
	_log("Server starting game with default ruleset.")
	game_manager.start_game()
	if turn_flow != null:
		turn_flow.reset_claim_tracking()
	_send_private_hands()
	Game_State_Manager.send_round_update(game_manager.round_number, game_manager.get_player_name(game_manager.current_player_index))
	_broadcast_game_state()

func _send_private_hands() -> void:
	if game_manager == null:
		return
	for pid in players.keys():
		var hand_data: Array = game_manager.serialize_hand_for_peer(pid)
		_log("Sending private hand to peer %s with %d cards." % [str(pid), hand_data.size()])
		Game_State_Manager.rpc_id(pid, "receive_private_hand", hand_data)
		_send_private_put_down_buffer_to_peer(pid)

func _send_private_hand_to_peer(peer_id: int) -> void:
	if game_manager == null:
		return
	var hand_data: Array = game_manager.serialize_hand_for_peer(peer_id)
	Game_State_Manager.rpc_id(peer_id, "receive_private_hand", hand_data)
	_send_private_put_down_buffer_to_peer(peer_id)

func _send_private_put_down_buffer_to_peer(peer_id: int) -> void:
	if game_manager == null:
		return
	var staged_cards_data: Array = game_manager.get_put_down_buffer_for_peer(peer_id)
	Game_State_Manager.send_private_put_down_buffer(peer_id, staged_cards_data)

func _reject_put_down(peer_id: int, reason: String) -> void:
	_log("Put-down rejected for %s: %s" % [str(peer_id), reason])
	Game_State_Manager.send_put_down_error(peer_id, reason)

func _handle_round_finished(finishing_peer_id: int, finish_message: String) -> void:
	if game_manager == null:
		return
	_log(finish_message)
	var completion: Dictionary = game_manager.complete_current_round(finishing_peer_id)
	if turn_flow != null:
		turn_flow.reset_claim_tracking()
	var completed_round: int = int(completion.get("completed_round", game_manager.round_number))
	var max_rounds: int = int(completion.get("max_rounds", game_manager.get_max_rounds()))
	var round_score: Dictionary = completion.get("round_score", {})
	var game_finished: bool = bool(completion.get("game_over", game_manager.game_over))
	var score_log: String = _format_round_score_log(round_score, completed_round)
	if not score_log.is_empty():
		_log(score_log)
	if game_finished:
		var winner_ids: Array = game_manager.get_winning_peer_ids()
		var winner_names: String = _winner_names_text(winner_ids)
		_log("Game complete at round %d/%d. Winner(s): %s" % [completed_round, max_rounds, winner_names])
		Game_State_Manager.send_round_update(game_manager.round_number, "Game Over: %s" % winner_names)
		_broadcast_game_state()
		return
	_send_private_hands()
	Game_State_Manager.send_round_update(
		game_manager.round_number,
		game_manager.get_player_name(game_manager.current_player_index)
	)
	_broadcast_game_state()

func _format_round_score_log(round_score: Dictionary, fallback_round: int) -> String:
	if round_score.is_empty():
		return ""
	var round_number: int = int(round_score.get("round", fallback_round))
	var rows_raw: Variant = round_score.get("rows", [])
	if typeof(rows_raw) != TYPE_ARRAY:
		return ""
	var parts: Array[String] = []
	var rows: Array = rows_raw
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		parts.append("%s +%d (total=%d)" % [
			str(row.get("name", "Unknown")),
			int(row.get("round_points", 0)),
			int(row.get("total_points", 0))
		])
	if parts.is_empty():
		return ""
	return "Round %d scores: %s" % [round_number, ", ".join(parts)]

func _winner_names_text(winner_ids: Array) -> String:
	if game_manager == null:
		return "unknown"
	var names: Array[String] = []
	for raw_winner_id in winner_ids:
		var winner_peer_id: int = int(raw_winner_id)
		names.append(game_manager.get_player_name_for_peer(winner_peer_id))
	if names.is_empty():
		return "unknown"
	return ", ".join(names)

func _all_connected_players_voted_play_again() -> bool:
	if int(players.size()) < 2:
		return false
	for raw_peer_id in players.keys():
		var peer_id: int = int(raw_peer_id)
		if not play_again_votes.has(peer_id):
			return false
	return true

func _play_again_vote_peer_ids() -> Array:
	var ids: Array = []
	for raw_peer_id in play_again_votes.keys():
		ids.append(int(raw_peer_id))
	ids.sort()
	return ids

func _restart_game_from_play_again_votes() -> void:
	play_again_restart_pending = false
	if players.is_empty():
		_end_game_session("No players remain for play-again restart.")
		return
	if int(players.size()) < 2:
		_return_to_lobby_with_connected_players("Not enough players to restart game.")
		return
	_log("All connected players voted play again. Restarting game.")
	play_again_votes.clear()
	ready_players.clear()
	for raw_peer_id in players.keys():
		var peer_id: int = int(raw_peer_id)
		if players.has(peer_id) and players[peer_id] is Player:
			(players[peer_id] as Player).ready = false
	_broadcast_player_state()
	start_game()

func _end_game_session(reason: String) -> void:
	_log("Ending game session: %s" % reason)
	play_again_restart_pending = false
	play_again_votes.clear()
	ready_players.clear()
	if turn_flow != null:
		turn_flow.reset_claim_tracking()
	if game_manager != null:
		game_manager.end_game_session()

func _return_to_lobby_with_connected_players(reason: String) -> void:
	_log("Returning to start screen: %s" % reason)
	play_again_restart_pending = false
	play_again_votes.clear()
	ready_players.clear()
	for raw_peer_id in players.keys():
		var peer_id: int = int(raw_peer_id)
		if players.has(peer_id) and players[peer_id] is Player:
			(players[peer_id] as Player).ready = false
	if game_manager != null:
		game_manager.end_game_session()
		game_manager.load_players(players)
	_broadcast_player_state()
	_broadcast_game_state()
	_broadcast_host_if_changed()
	Game_State_Manager.send_change_scene(RETURN_TO_MENU_SCENE_PATH)

func _schedule_play_again_restart_validation() -> void:
	if play_again_restart_pending:
		return
	play_again_restart_pending = true
	var timer: SceneTreeTimer = get_tree().create_timer(PLAY_AGAIN_RESTART_DELAY_SECONDS, false)
	timer.timeout.connect(func() -> void:
		play_again_restart_pending = false
		if not _ensure_game_manager_bound():
			return
		if not game_manager.game_over:
			return
		if int(players.size()) < 2:
			if not play_again_votes.is_empty():
				_return_to_lobby_with_connected_players("Play-again validation found fewer than two connected players.")
			return
		if _all_connected_players_voted_play_again():
			_restart_game_from_play_again_votes()
			return
		_broadcast_game_state()
	)

func _validate_card_for_meld_add(meld_data: Dictionary, card: Card) -> Dictionary:
	if card == null:
		return {
			"ok": false,
			"reason": "Invalid card."
		}
	var cards_data_variant: Variant = meld_data.get("cards_data", [])
	if typeof(cards_data_variant) != TYPE_ARRAY:
		return {
			"ok": false,
			"reason": "Target meld is invalid."
		}
	var meld_cards: Array[Card] = []
	var cards_data: Array = cards_data_variant
	for raw_card in cards_data:
		if typeof(raw_card) != TYPE_DICTIONARY:
			return {
				"ok": false,
				"reason": "Target meld is invalid."
			}
		meld_cards.append(Card.from_dict(raw_card))

	var group_type: String = str(meld_data.get("group_type", ""))
	match group_type:
		PutDownValidator.GROUP_SET_3:
			var set_cards: Array[Card] = meld_cards.duplicate()
			set_cards.append(card)
			var set_number: int = int(meld_data.get("set_number", -1))
			return PutDownValidator.validate_set_cards(set_cards, set_number)
		PutDownValidator.GROUP_RUN_4, PutDownValidator.GROUP_RUN_7:
			var run_suit: int = int(meld_data.get("run_suit", -1))
			return PutDownValidator.validate_run_add_to_ends(meld_cards, card, run_suit)
		_:
			return {
				"ok": false,
				"reason": "Unsupported meld type."
			}

func _ensure_game_manager_bound() -> bool:
	if game_manager == null:
		_bind_game_manager()
	return game_manager != null

func _debug_ui_enabled() -> bool:
	return bool(ProjectSettings.get_setting(DEBUG_UI_SETTING_PATH, false))

func _apply_turn_flow_result(result: Dictionary) -> bool:
	for raw_message in result.get("log_messages", []):
		_log(str(raw_message))

	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "Turn Flow move rejected."))
		var put_down_error_peer_id: int = int(result.get("put_down_error_peer_id", -1))
		if put_down_error_peer_id > 0:
			_reject_put_down(put_down_error_peer_id, reason)
		else:
			_log(reason)
		return false

	var round_finished: Dictionary = result.get("round_finished", {})
	if not round_finished.is_empty():
		_handle_round_finished(
			int(round_finished.get("peer_id", -1)),
			str(round_finished.get("message", "Round is over."))
		)
		return true

	for raw_peer_id in result.get("private_hand_peer_ids", []):
		_send_private_hand_to_peer(int(raw_peer_id))
	for raw_peer_id in result.get("private_put_down_peer_ids", []):
		_send_private_put_down_buffer_to_peer(int(raw_peer_id))

	var claim_notification: Dictionary = result.get("claim_notification", {})
	if not claim_notification.is_empty():
		Game_State_Manager.send_pile_claimed_notification(
			int(claim_notification.get("claimant_peer_id", -1)),
			claim_notification.get("card_data", {}),
			bool(claim_notification.get("extra_card_drawn", false))
		)
	var claim_passed_peer_id: int = int(result.get("claim_passed_peer_id", -1))
	if claim_passed_peer_id > 0:
		Game_State_Manager.send_claim_passed_notification(claim_passed_peer_id)

	var round_update: Dictionary = result.get("round_update", {})
	if not round_update.is_empty():
		Game_State_Manager.send_round_update(
			int(round_update.get("round", game_manager.round_number)),
			str(round_update.get("current_player_name", game_manager.get_player_name(game_manager.current_player_index)))
		)

	var claim_timer_claim_id: int = int(result.get("claim_timer_claim_id", -1))
	if claim_timer_claim_id != -1:
		var claim_timer: SceneTreeTimer = get_tree().create_timer(float(CLAIM_WINDOW_SECONDS), false)
		claim_timer.timeout.connect(func ():
			if not _ensure_game_manager_bound():
				return
			var expiry_result: Dictionary = _ensure_turn_flow().apply_move(0, {
				"type": "expire_claim",
				"claim_window_id": claim_timer_claim_id
			})
			_apply_turn_flow_result(expiry_result)
		)

	if bool(result.get("public_state_changed", false)):
		_broadcast_game_state()
	return true

func register_hand_reorder(peer_id: int, cards_data: Array) -> void:
	if game_manager == null:
		_bind_game_manager()
	if game_manager == null:
		_log_err("Ignoring hand reorder from %s: GameManager unavailable." % str(peer_id))
		return
	if not players.has(peer_id):
		_log_err("Ignoring hand reorder from unknown peer %s." % str(peer_id))
		return
	if not game_manager.player_hands.has(peer_id):
		_log_err("Ignoring hand reorder from peer %s: no authoritative hand." % str(peer_id))
		return

	var existing_hand: Array = game_manager.player_hands[peer_id]
	if cards_data.size() != existing_hand.size():
		_log_err("Rejecting hand reorder from peer %s: card count mismatch %d != %d." % [
			str(peer_id), cards_data.size(), existing_hand.size()
		])
		return

	var existing_counts: Dictionary = _build_signature_counts_from_cards(existing_hand)
	var incoming_cards: Array[Card] = []
	var incoming_counts: Dictionary = _build_signature_counts_from_dicts(cards_data, incoming_cards)
	if incoming_counts.is_empty() and cards_data.size() > 0:
		_log_err("Rejecting hand reorder from peer %s: malformed payload." % str(peer_id))
		return
	if not _signature_counts_equal(existing_counts, incoming_counts):
		_log_err("Rejecting hand reorder from peer %s: card identity mismatch." % str(peer_id))
		return

	game_manager.player_hands[peer_id] = incoming_cards
	_log("Applied hand reorder from peer %s." % str(peer_id))

	# Echo back authoritative order to keep client state in sync.
	var hand_data: Array = game_manager.serialize_hand_for_peer(peer_id)
	Game_State_Manager.rpc_id(peer_id, "receive_private_hand", hand_data)

func _build_signature_counts_from_cards(cards: Array) -> Dictionary:
	var counts: Dictionary = {}
	for entry in cards:
		if not (entry is Card):
			continue
		var card: Card = entry as Card
		_increment_signature_count(counts, _card_signature(card.suit, card.number, card.point_value))
	return counts

func _build_signature_counts_from_dicts(cards_data: Array, out_cards: Array[Card]) -> Dictionary:
	var counts: Dictionary = {}
	for raw in cards_data:
		if typeof(raw) != TYPE_DICTIONARY:
			return {}
		var card_dict: Dictionary = raw
		var card: Card = Card.from_dict(card_dict)
		out_cards.append(card)
		_increment_signature_count(counts, _card_signature(card.suit, card.number, card.point_value))
	return counts

func _signature_counts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
		if int(a[key]) != int(b[key]):
			return false
	return true

func _signature_counts_subset(subset: Dictionary, superset: Dictionary) -> bool:
	for key in subset.keys():
		var subset_value: int = int(subset.get(key, 0))
		var superset_value: int = int(superset.get(key, 0))
		if subset_value > superset_value:
			return false
	return true

func _subtract_signature_counts(source: Dictionary, to_subtract: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		var source_value: int = int(source.get(key, 0))
		var subtract_value: int = int(to_subtract.get(key, 0))
		if subtract_value > source_value:
			return {}
		var remaining: int = source_value - subtract_value
		if remaining > 0:
			result[key] = remaining
	return result

func _increment_signature_count(counts: Dictionary, signature: String) -> void:
	var current: int = int(counts.get(signature, 0))
	counts[signature] = current + 1

func _card_signature(suit: int, number: int, point_value: int) -> String:
	return "%d|%d|%d" % [suit, number, point_value]
