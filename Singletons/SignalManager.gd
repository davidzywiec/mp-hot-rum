extends Node

signal player_disconnected(player_id)
signal player_connected(player_id)
signal server_connected
signal server_disconnected
signal failed_connection

signal start_server
signal join_server(adress)
signal refresh_lobby
signal player_ready(ready)
signal ready_to_start(bool)
signal toggle_game_countdown(bool)

# NEW: broadcast a scene change with a path determined by the server
signal change_scene(path: String)

signal host_changed(peer_id: int)
