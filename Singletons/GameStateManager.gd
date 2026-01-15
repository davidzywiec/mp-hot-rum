# GameStateManager.gd
extends Node
class_name GameStateManager

signal player_state_updated(players_data: Array)
signal countdown_toggle(flag: bool)
# NEW: precise end timestamp in unix seconds for synced countdowns
signal countdown_sync(end_unix: int)

var current_player : Player
var latest_player_state: Array = []

func _ready():
	print("GameStateManager is alive!")

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
	print("Received: Game starting (bool)")
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
	print("⏱ Received synced countdown end:", end_unix)
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
	print("🎬 Change scene requested:", path)
	# Let UI react (or change directly here if you prefer)
	SignalManager.change_scene.emit(path)

func send_change_scene(path: String) -> void:
	rpc("receive_change_scene", path)
	SignalManager.change_scene.emit(path)

# --- Host assignment sync ---
@rpc
func receive_host(new_host_peer_id: int) -> void:
	print("👑 New host is:", new_host_peer_id)
	SignalManager.ready_to_start.emit(false) # default off; UI will recompute
	# Let UI know so it can enable/disable Start for the right player
	SignalManager.emit_signal("host_changed", new_host_peer_id)

func send_host(new_host_peer_id: int) -> void:
	rpc("receive_host", new_host_peer_id)
	SignalManager.emit_signal("host_changed", new_host_peer_id)
