# ServerHandler.gd
# Implements server-specific networking behavior

extends Node
class_name ServerHandler

const PORT = 7000
const MAX_CONNECTIONS = 6
const NETWORK_LOG_SETTING_PATH := "debug/network_logs"
const SNAPSHOT_LOG_SETTING_PATH := "debug/snapshot_logs"

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
var players := {} # key: player_name, value: Player
var ready_players := {}
var game_manager = null

# TODO: point this at your actual game scene when its added
const GAME_SCENE_PATH := "res://scenes/game/MainGame.tscn"

# Initializes the server and sets it as the active multiplayer peer
func start():
	var peer = ENetMultiplayerPeer.new()

	# Attempt to bind server on the given port with max allowed clients
	var error = peer.create_server(PORT, MAX_CONNECTIONS)

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
		var player = Player.new()
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
	var ids := []
	# Prefer authoritative list; use the registries you maintain
	for pid in players.keys():
		ids.append(pid)
	ids.sort()
	if ids.size() > 0:
		return ids[0]
	else:
		return -1

func _broadcast_host_if_changed() -> void:
	var host := _current_host_peer_id()
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
	var snapshot := {
		"players": state_players,
		"player_order_ids": order_ids,
		"round_number": game_manager.round_number,
		"current_player_index": game_manager.current_player_index,
		"starting_player_index": game_manager.starting_player_index
	}
	if ProjectSettings.get_setting(SNAPSHOT_LOG_SETTING_PATH, false):
		_log("Snapshot: %s" % str(snapshot))
	Game_State_Manager.send_game_state(snapshot)

# Sync Countdown to start game (SERVER-AUTHORITATIVE)
func _toggle_countdown(flag: bool, sec: float = 10.0) -> void:
	if flag:
		var args := OS.get_cmdline_args()
		if ProjectSettings.get_setting("debug/short_countdown", false) or args.has("--short-countdown"):
			sec = 1.0
		_log("Server starting countdown to start game! seconds=%s short_setting=%s args=%s" % [
			str(sec),
			str(ProjectSettings.get_setting("debug/short_countdown", false)),
			str(args)
		])
		var seconds := sec
		var end_unix := Time.get_unix_time_from_system() + seconds
		# Broadcast exact end time to every client
		Game_State_Manager.send_countdown(end_unix)
		# Schedule the scene change on the server
		var t := get_tree().create_timer(float(seconds), false)
		t.timeout.connect(func ():
			_log("Countdown finished - ordering scene change")
			start_game()
			Game_State_Manager.send_change_scene(GAME_SCENE_PATH)
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

# for testing: Create fake players and start countdown
func create_fake_game() -> void:
	# Create 5 fake players and set them to ready.
	for i in range(5):
		register_player("Test Player " + str(i), i + 10)
		register_ready_flag(i + 10, true)
	_toggle_countdown(true, 1)
