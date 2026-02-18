# ServerHandler.gd
# Implements server-specific networking behavior

extends Node
class_name ServerHandler

const PORT: int = 7000
const MAX_CONNECTIONS: int = 6
const NETWORK_LOG_SETTING_PATH: String = "debug/network_logs"
const SNAPSHOT_LOG_SETTING_PATH: String = "debug/snapshot_logs"
const TURN_DEBUG: bool = true
const CLAIM_WINDOW_SECONDS: int = 30

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
		return
	if not get_node_or_null("/root/GameManager"):
		_log_err("GameManager autoload not found; cannot bind server game state.")
		return
	game_manager = get_node("/root/GameManager")

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

func register_end_turn(peer_id: int) -> void:
	if game_manager == null:
		_bind_game_manager()
	if game_manager == null:
		_log_err("Ignoring end turn from %s: GameManager unavailable." % str(peer_id))
		return
	if not players.has(peer_id):
		_log_err("Ignoring end turn from unknown peer %s." % str(peer_id))
		return

	var current_turn_peer_id: int = game_manager.get_current_player_peer_id()
	if TURN_DEBUG:
		_log("[TURN_DEBUG][SERVER][register_end_turn] sender=%s current_turn_peer=%s current_idx=%d order_size=%d" % [
			str(peer_id),
			str(current_turn_peer_id),
			int(game_manager.current_player_index),
			int(game_manager.player_order.size())
		])
	if current_turn_peer_id == -1:
		_log_err("Ignoring end turn from %s: no active current player." % str(peer_id))
		return
	if current_turn_peer_id != peer_id:
		_log("Ignoring end turn from peer %s: current turn belongs to %s." % [
			str(peer_id), str(current_turn_peer_id)
		])
		return
	if not game_manager.turn_discard_completed:
		_log("Ignoring end turn from peer %s: they must discard before ending their turn." % str(peer_id))
		return

	# TODO: Gate end-turn with full rules validation (melded sets/runs and go-out/end-game checks).
	game_manager.advance_to_next_player()
	_log("Turn ended by peer %s. Next player is %s." % [
		str(peer_id), game_manager.get_player_name(game_manager.current_player_index)
	])
	Game_State_Manager.send_round_update(
		game_manager.round_number,
		game_manager.get_player_name(game_manager.current_player_index)
	)
	_broadcast_game_state()

func register_draw_from_deck(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	if not _validate_turn_action_peer(peer_id):
		return
	if game_manager.turn_pickup_completed:
		_log("Ignoring draw request from %s: turn pickup already completed." % str(peer_id))
		return
	if game_manager.claim_window_active:
		_log("Ignoring draw request from %s while claim window is active." % str(peer_id))
		return
	var drawn_card: Card = game_manager.draw_card_from_deck_for_peer(peer_id)
	if drawn_card == null:
		_log_err("Draw from deck failed for peer %s (deck empty or unavailable)." % str(peer_id))
		return
	game_manager.mark_turn_pickup_completed()
	_send_private_hand_to_peer(peer_id)
	_broadcast_game_state()

func register_discard_card(peer_id: int, card_data: Dictionary) -> void:
	if not _ensure_game_manager_bound():
		return
	if not _validate_turn_action_peer(peer_id):
		return
	if game_manager.claim_window_active:
		_log("Ignoring discard request from %s while claim window is active." % str(peer_id))
		return
	if not game_manager.turn_pickup_completed:
		_log("Ignoring discard request from %s: player must pick up a card first." % str(peer_id))
		return
	if game_manager.turn_discard_completed:
		_log("Ignoring discard request from %s: discard already completed this turn." % str(peer_id))
		return
	if card_data.is_empty():
		_log_err("Ignoring discard request from %s: invalid card payload." % str(peer_id))
		return

	var discarded_card: Card = game_manager.discard_card_from_peer(peer_id, card_data)
	if discarded_card == null:
		_log_err("Discard request from %s failed: card not found in hand." % str(peer_id))
		return

	game_manager.mark_turn_discard_completed()
	_send_private_hand_to_peer(peer_id)

	var remaining_cards: int = game_manager.get_hand_size_for_peer(peer_id)
	if remaining_cards <= 0:
		_log("Peer %s discarded their final card %s. Round is over." % [str(peer_id), str(discarded_card)])
		game_manager.advance_to_next_round()
		_send_private_hands()
		Game_State_Manager.send_round_update(
			game_manager.round_number,
			game_manager.get_player_name(game_manager.current_player_index)
		)
		_broadcast_game_state()
		return

	_broadcast_game_state()

func register_take_from_pile(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	if not _validate_turn_action_peer(peer_id):
		return
	if game_manager.turn_pickup_completed:
		_log("Ignoring take-pile request from %s: turn pickup already completed." % str(peer_id))
		return
	if game_manager.claim_window_active:
		_log("Ignoring take-pile request from %s while claim window is active." % str(peer_id))
		return
	var taken_card: Card = game_manager.take_discard_top_for_peer(peer_id)
	if taken_card == null:
		_log_err("Take from pile failed for peer %s (pile empty)." % str(peer_id))
		return
	game_manager.mark_turn_pickup_completed()
	_send_private_hand_to_peer(peer_id)
	_broadcast_game_state()

func register_pass_pile(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	if not _validate_turn_action_peer(peer_id):
		return
	if game_manager.turn_pickup_completed:
		_log("Ignoring pass-pile request from %s: turn pickup already completed." % str(peer_id))
		return
	if game_manager.claim_window_active:
		_log("Ignoring pass-pile request from %s: claim window already active." % str(peer_id))
		return
	if game_manager.get_discard_top_card() == null:
		_log("Ignoring pass-pile request from %s: discard pile is empty." % str(peer_id))
		return
	var claim_id: int = game_manager.open_claim_window(peer_id, CLAIM_WINDOW_SECONDS)
	if claim_id == -1:
		_log_err("Failed to open claim window for peer %s." % str(peer_id))
		return
	_log("Peer %s passed pile card. Opened %d second claim window." % [str(peer_id), CLAIM_WINDOW_SECONDS])
	_broadcast_game_state()
	var claim_timer: SceneTreeTimer = get_tree().create_timer(float(CLAIM_WINDOW_SECONDS), false)
	claim_timer.timeout.connect(func ():
		_finalize_claim_window_if_open(claim_id)
	)

func register_claim_pile(peer_id: int) -> void:
	if not _ensure_game_manager_bound():
		return
	if not players.has(peer_id):
		_log_err("Ignoring claim request from unknown peer %s." % str(peer_id))
		return
	if not game_manager.claim_window_active:
		_log("Ignoring claim request from %s: no active claim window." % str(peer_id))
		return
	if game_manager.claim_opened_by_peer_id == peer_id:
		_log("Ignoring claim request from %s: opener cannot claim their own passed pile card." % str(peer_id))
		return
	var now_unix: int = int(Time.get_unix_time_from_system())
	if game_manager.claim_deadline_unix > 0 and now_unix > game_manager.claim_deadline_unix:
		_finalize_claim_window_if_open(game_manager.claim_window_id)
		return

	var claimed_card: Card = game_manager.take_discard_top_for_peer(peer_id)
	if claimed_card == null:
		_log_err("Claim request from %s failed: discard pile empty." % str(peer_id))
		_finalize_claim_window_if_open(game_manager.claim_window_id)
		return

	var extra_card: Card = game_manager.draw_card_from_deck_for_peer(peer_id)
	game_manager.clear_claim_window()
	_send_private_hand_to_peer(peer_id)
	Game_State_Manager.send_pile_claimed_notification(peer_id, claimed_card.to_dict(), extra_card != null)
	var extra_draw_text: String = "did not draw"
	if extra_card != null:
		extra_draw_text = "drew"
	_log("Peer %s claimed pile card %s and %s an extra deck card." % [
		str(peer_id),
		str(claimed_card),
		extra_draw_text
	])
	_broadcast_game_state()

# Called when a player disconnects
func _on_peer_disconnected(peer_id: int) -> void:
	_log("Peer %d disconnected." % peer_id)
	# Optional: implement disconnection cleanup if you store peer_id -> name mapping
	players.erase(peer_id)
	ready_players.erase(peer_id)
	if game_manager != null:
		game_manager.load_players(players)
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
		"turn_pickup_completed": game_manager.turn_pickup_completed,
		"turn_discard_completed": game_manager.turn_discard_completed
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
	_log("Server loading players into game.")
	game_manager.load_players(players)
	_log("Server starting game with default ruleset.")
	game_manager.start_game()
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

func _send_private_hand_to_peer(peer_id: int) -> void:
	if game_manager == null:
		return
	var hand_data: Array = game_manager.serialize_hand_for_peer(peer_id)
	Game_State_Manager.rpc_id(peer_id, "receive_private_hand", hand_data)

func _ensure_game_manager_bound() -> bool:
	if game_manager == null:
		_bind_game_manager()
	return game_manager != null

func _validate_turn_action_peer(peer_id: int) -> bool:
	if not players.has(peer_id):
		_log_err("Ignoring request from unknown peer %s." % str(peer_id))
		return false
	var current_turn_peer_id: int = game_manager.get_current_player_peer_id()
	if current_turn_peer_id == -1:
		_log_err("Ignoring request from %s: no active current player." % str(peer_id))
		return false
	if current_turn_peer_id != peer_id:
		_log("Ignoring request from %s: current turn belongs to %s." % [
			str(peer_id), str(current_turn_peer_id)
		])
		return false
	return true

func _finalize_claim_window_if_open(expected_claim_id: int) -> void:
	if game_manager == null:
		return
	if not game_manager.claim_window_active:
		return
	if game_manager.claim_window_id != expected_claim_id:
		return
	_log("Claim window timed out with no winner.")
	game_manager.clear_claim_window()
	_broadcast_game_state()

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

func _increment_signature_count(counts: Dictionary, signature: String) -> void:
	var current: int = int(counts.get(signature, 0))
	counts[signature] = current + 1

func _card_signature(suit: int, number: int, point_value: int) -> String:
	return "%d|%d|%d" % [suit, number, point_value]
