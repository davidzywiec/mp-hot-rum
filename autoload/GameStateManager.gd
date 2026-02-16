# GameStateManager.gd
extends Node
class_name GameStateManager

signal player_state_updated(players_data: Array)
signal countdown_toggle(flag: bool)
# precise end timestamp in unix seconds for synced countdowns
signal countdown_sync(end_unix: int)
signal game_state_updated(state: Dictionary)
signal private_hand_updated(cards: Array)

const SNAPSHOT_LOG_SETTING_PATH := "debug/snapshot_logs"

var current_player : Player
var latest_player_state: Array = []

func _is_server_authority() -> bool:
	return multiplayer.is_server() or OS.has_feature("server")

func _log_server(msg: String) -> void:
	if not _is_server_authority():
		return
	print(msg)

func _ready():
	_log_server("GameStateManager is alive!")

# ------------------------------
# EXISTING (trimmed for brevity)
# ------------------------------
@rpc
func receive_player_state(players_data: Array) -> void:
	latest_player_state = players_data
	emit_signal("player_state_updated", players_data)

func send_player_state(players_data: Array) -> void:
	rpc("receive_player_state", players_data)
	emit_signal("player_state_updated", players_data)

# EXISTING: legacy boolean toggle (kept)
@rpc
func receive_toggle_countdown(start_timer: bool) -> void:
	_log_server("Received: Game starting (bool)")
	emit_signal("countdown_toggle", start_timer)
	SignalManager.toggle_game_countdown.emit(start_timer)

func send_toggle_countdown(start_timer: bool) -> void:
	rpc("receive_toggle_countdown", start_timer)
	emit_signal("countdown_toggle", start_timer)
	SignalManager.toggle_game_countdown.emit(start_timer)

# ------------------------------
# NEW: synced countdown support
# ------------------------------
@rpc
func receive_countdown(end_unix: int) -> void:
	# Fired on all peers, including server
	_log_server("Received synced countdown end: %s" % str(end_unix))
	emit_signal("countdown_sync", end_unix)
	# Also drive the existing boolean signal so legacy UI keeps working
	emit_signal("countdown_toggle", true)
	SignalManager.toggle_game_countdown.emit(true)

func send_countdown(end_unix: int) -> void:
	rpc("receive_countdown", end_unix)
	emit_signal("countdown_sync", end_unix)
	emit_signal("countdown_toggle", true)
	SignalManager.toggle_game_countdown.emit(true)

# ------------------------------
# NEW: scene change broadcast
# ------------------------------
@rpc
func receive_change_scene(path: String) -> void:
	_log_server("Change scene requested: %s" % path)
	# Let UI react (or change directly here if you prefer)
	SignalManager.change_scene.emit(path)

func send_change_scene(path: String) -> void:
	rpc("receive_change_scene", path)
	SignalManager.change_scene.emit(path)

# --- Host assignment sync ---
@rpc
func receive_host(new_host_peer_id: int) -> void:
	_log_server("New host is: %s" % str(new_host_peer_id))
	SignalManager.ready_to_start.emit(false) # default off; UI will recompute
	# Let UI know so it can enable/disable Start for the right player
	SignalManager.emit_signal("host_changed", new_host_peer_id)

func send_host(new_host_peer_id: int) -> void:
	rpc("receive_host", new_host_peer_id)
	SignalManager.emit_signal("host_changed", new_host_peer_id)

## --- Round Update Sync ---
@rpc
func receive_round_update(round: int, current_player_name: String) -> void:
	_log_server("Received round update: Round %d, Current Player: %s" % [round, current_player_name])
	SignalManager.round_updated.emit(round, current_player_name)

func send_round_update(round: int, current_player_name: String) -> void:
	rpc("receive_round_update", round, current_player_name)
	SignalManager.round_updated.emit(round, current_player_name)

# ------------------------------
# NEW: game state snapshot sync
# ------------------------------
@rpc
func receive_game_state(state: Dictionary) -> void:
	emit_signal("game_state_updated", state)

func send_game_state(state: Dictionary) -> void:
	if _is_server_authority() and ProjectSettings.get_setting(SNAPSHOT_LOG_SETTING_PATH, false):
		print("Sending game state snapshot:", state)
	rpc("receive_game_state", state)
	emit_signal("game_state_updated", state)

@rpc("authority")
func receive_private_hand(cards_or_peer, maybe_cards = null) -> void:
	var cards: Array = []
	if maybe_cards != null:
		# Compatibility path if sender provides (peer_id, cards).
		cards = maybe_cards
	else:
		cards = cards_or_peer
	print("receive_private_hand called. cards=%d args_shape=%s" % [
		cards.size(),
		"two-arg" if maybe_cards != null else "one-arg"
	])
	GameManager.apply_private_hand(cards)
	emit_signal("private_hand_updated", cards)
