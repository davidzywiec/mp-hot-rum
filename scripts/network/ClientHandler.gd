# ClientHandler.gd
# Handles client-specific logic for connecting to a server

extends Node
class_name ClientHandler

const PORT: int = 7000

# Start a connection to a server at the given address
func start(address: String):
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(address, PORT)

	if error != OK:
		print("❌ Failed to connect to server. Error code:", error)
		SignalManager.failed_connection.emit()
		return

	# Set the peer first
	multiplayer.multiplayer_peer = peer

	# THEN connect to scene tree multiplayer signals
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	print("✅ Attempting to connect to server at %s:%d..." % [address, PORT])
	
	
func _on_connection_success():
	print("✅ Successfully connected to server.")
	SignalManager.server_connected.emit()
	

func _on_connection_failed():
	print("❌ Connection to server failed.")
	SignalManager.failed_connection.emit()

func _on_server_disconnected():
	print("🔌 Disconnected from server.")
	SignalManager.failed_connection.emit()

func broadcast_ready_flag(peer_id: int, ready_status: bool):
	#Register Player Username with server
	Network_Manager.rpc_id(1, "register_ready_flag", peer_id, ready_status)
