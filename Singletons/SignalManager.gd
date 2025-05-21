extends Node

signal player_disconnected(player_id)
signal player_connected(player_id)
signal server_connected
signal server_disconnected
signal failed_connection

signal start_server
signal join_server(adress)
signal refresh_lobby
signal register_username(username)
signal player_ready(ready)
signal ready_to_start(bool)
signal start_game_countdown()
