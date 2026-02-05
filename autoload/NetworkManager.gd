# NetworkManager.gd
# Facade to abstract away network setup from the rest of the game

extends Node
class_name NetworkManager

# Holds the current network role handler (e.g., server, client, host)
var handler = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var args := OS.get_cmdline_args()
	if args.has("--server"):
		call_deferred("_boot_dedicated_server")
	elif args.has("--client"):
		# Explicit client flag: keep normal startup path
		return

func _boot_dedicated_server() -> void:
	var server_scene := "res://scenes/server/DedicatedServer.tscn"
	var tree := get_tree()
	if tree.current_scene != null and tree.current_scene.scene_file_path == server_scene:
		return
	tree.change_scene_to_file(server_scene)

# Called by UI or SignalManager to start the server
func start_server():
	# Create a new instance of the ServerHandler (Strategy)
	handler = ServerHandler.new()
	
	# Add it to the scene tree so it can function properly
	add_child(handler)

	# Delegate the server startup to the handler
	handler.start()

func join_server(address: String):
	handler = ClientHandler.new()
	add_child(handler)
	handler.start(address)
	
@rpc("any_peer")
func register_player(player_name: String, peer_id : int):
	if handler is ServerHandler:
		print("Received username from client: %s" % player_name)
		handler.register_player(player_name, peer_id)

@rpc("any_peer")
func register_ready_flag(peer_id: int, ready_flag: bool):
	if handler is ServerHandler:
		handler.register_ready_flag(peer_id, ready_flag)

@rpc("any_peer")
func register_countdown(peer_id: int, flag: bool, countdown_time: int = 10):
	if handler is ServerHandler:
		handler._toggle_countdown(flag, countdown_time)

func is_server() -> bool:
	return handler is ServerHandler
