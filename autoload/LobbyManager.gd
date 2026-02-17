extends Node

const PORT: int = 7000
const MAX_CONNECTIONS: int = 6

enum LobbyState {
	WAITING_FOR_PLAYERS,
	READY_CHECK,
	READY_TO_START,
	CANCEL_START,
	STARTING_GAME
}
var state: int = LobbyState.WAITING_FOR_PLAYERS

#Player registries
var players: Dictionary = {} # key: peer_id, value: player_data
#Players ready
var ready_players: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)
	multiplayer.connected_to_server.connect(server_connected)
	multiplayer.server_disconnected.connect(server_disconnected)
	multiplayer.connection_failed.connect(failed_connection)
	SignalManager.start_server.connect(start_server)
	SignalManager.join_server.connect(join_server)
	SignalManager.register_username.connect(register_username)
	SignalManager.player_ready.connect(register_ready_flag)

## Starts the game server using ENet for multiplayer networking.
## This sets up the host to accept incoming player connections.
func start_server():
	# Create a new ENet peer to act as the server
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	
	# Attempt to create the server with specified port and max connections.
	# The last three zeroes are for:
	# - In-bandwidth (0 = unlimited)
	# - Out-bandwidth (0 = unlimited)
	# - Channel count (0 = default)
	var error: int = peer.create_server(PORT, MAX_CONNECTIONS, 0, 0, 0)
	
	# If there's an error creating the server, return it (non-zero means failure)
	if error:
		return error
	
	# Set the server as the active multiplayer peer in the scene tree
	multiplayer.multiplayer_peer = peer

##Joins the game server using ENet for mulitplayer networking.
func join_server(address: String):
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(address, PORT)
	if error:
		SignalManager.failed_connection.emit()
		return
		
	multiplayer.multiplayer_peer = peer

func player_connected(user_id: int) -> void:
	var peer_id: int = multiplayer.get_unique_id()
	#If server receiving player connected register the user.
	if peer_id == 1:
		register_player(user_id)
	else:
		SignalManager.player_connected.emit(user_id)


func register_player(new_player_info: Variant) -> void:
	if !players.has(new_player_info):
		players[new_player_info] = {
			"Name" : new_player_info,
			"Ready": false
			}
	print("%s has joined the game!" % str(new_player_info))
	SignalManager.player_connected.emit(new_player_info)
	sync_lobby_data_to_all()


func player_disconnected(user_id: int) -> void:
	players.erase(user_id)
	SignalManager.player_disconnected.emit(user_id)
	print("Player disconnected %s" % str(user_id))
	sync_lobby_data_to_all()
	SignalManager.refresh_lobby.emit()
	
	
func failed_connection() -> void:
	multiplayer.multiplayer_peer = null
	SignalManager.failed_connection.emit()
	print("Failed connection occured!")

func server_connected() -> void:
	SignalManager.server_connected.emit()
	print("Server connection started")

func server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	SignalManager.server_disconnected.emit()

func sync_lobby_data_to_all():
	for peer_id in multiplayer.get_peers():
		if peer_id != 1:
			rpc_id(peer_id, "receive_lobby_data", players, state)

@rpc
func receive_lobby_data(new_lobby_players, new_state):
	#clear_lobby_ui()
	players = new_lobby_players
	if typeof(new_state) is LobbyState:
		set_state(new_state)
	else:
		push_error("State passed not of LobbyState type!")
		return
		
	SignalManager.refresh_lobby.emit()

func register_username(username: String) -> void:
	#Register Player Username with server
	var peer_id: int = multiplayer.get_unique_id()
	rpc_id(1, "register_username_with_server", peer_id, username)

func register_ready_flag(ready: bool) -> void:
	#Register Player Username with server
	var peer_id: int = multiplayer.get_unique_id()
	rpc_id(1, "register_ready_with_server", peer_id, ready)

@rpc("any_peer")
func register_username_with_server(id: int, name: String) -> void:
	print("Registering player %s as %s" % [id, name])
	players[id]["Name"] = name
	sync_lobby_data_to_all()
	SignalManager.refresh_lobby.emit()

@rpc("any_peer")
func register_ready_with_server(id: int, ready: bool) -> void:
	print("Player %s: Ready = %s" % [id, ready])
	players[id]["Ready"] = ready
	print("Checking if all players are ready...")
	if check_all_ready():
		print("All Players are ready. Waiting for a player to start the Game.")
		set_state(LobbyState.READY_TO_START)
	elif state == LobbyState.READY_TO_START:
		set_state(LobbyState.WAITING_FOR_PLAYERS)
	else:
		print("All Players are NOT ready.")
	
	sync_lobby_data_to_all()
	SignalManager.refresh_lobby.emit()

func check_all_ready() -> bool:
	var all_ready: bool = true
	if players.size() < 3:
		return false
	for player in players.values():
		if not player.get("Ready", false):
			all_ready = false
			return false
	return all_ready
	

func set_state(new_state : LobbyState) -> void:
	#Don't do anything if state is unchanged
	if state == new_state:
		return
	
	#Transition to new state
	print("Transitiioning from %s state to %s state..." % [str(state), str(new_state)])
	if new_state == LobbyState.READY_TO_START:
		SignalManager.ready_to_start.emit(true)
	else:
		SignalManager.ready_to_start.emit(false)

	state = new_state
	
