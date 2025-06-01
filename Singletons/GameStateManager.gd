# GameStateManager.gd
extends Node
class_name GameStateManager

signal player_state_updated(players_data: Array)
var current_player : Player

# Optionally store current state for access
var latest_player_state: Array = []

func _ready():
	print("GameStateManager is alive!")
	
# Called by the server to send player info
@rpc
func receive_player_state(players_data: Array) -> void:
	latest_player_state = players_data
	print("📡 Received player state update")
	emit_signal("player_state_updated", players_data)
	
# Send player state to server
func send_player_state(player_state):
	rpc("receive_player_state", player_state)
