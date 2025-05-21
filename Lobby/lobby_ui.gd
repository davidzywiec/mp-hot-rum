extends Control

@onready
var player_container = $GridContainer
@onready
var player_card = preload("res://Lobby/player_card.tscn")
@onready
var ready_btn = $VBC/ReadyButton
@onready
var start_btn = $VBC/StartButton

var ready_status: bool = false

func _ready() -> void:
	SignalManager.player_connected.connect(player_connected)
	SignalManager.refresh_lobby.connect(refresh_lobby)
	SignalManager.ready_to_start.connect(set_ui_actions)
	set_ui_actions(false)
		
func player_connected(player_id) -> void:
	if LobbyManager.players.has(player_id):
		var player_data = LobbyManager.players[player_id]
		if typeof(player_data) == TYPE_DICTIONARY and player_data.has("Name"):
			var name = player_data["Name"]
			print("Player connected to lobby %s" % str(LobbyManager.players[player_id]))
			var player : player_card = player_card.instantiate()
			player_container.add_child(player)
			if player.has_method("set_username"):
				player.set_username(str(LobbyManager.players[player_id]["Name"]))
				player.set_ready((LobbyManager.players[player_id]["Ready"]))

		else:
			print("player_id exists but no 'name' key or not a dictionary: %s" % str(player_data))
	else:
		print("player_id not found in players: %s" % str(player_id))

func refresh_lobby() -> void:
	print("Refreshing lobby for...%s" % str(multiplayer.get_unique_id()))
	for node in player_container.get_children():
		node.queue_free()
	for player in LobbyManager.players.keys():
		player_connected(player)

func set_ready_flag() -> void:
	ready_status = !ready_status
	SignalManager.player_ready.emit(ready_status)

func set_ui_actions(ready: bool) -> void:
	if multiplayer.is_server():
		print("I am the host (server)")
		ready_btn.visible = false
		ready_btn.disabled = true
	else:
		if !(ready_btn.is_connected("pressed",set_ready_flag)):
			ready_btn.pressed.connect(set_ready_flag)
		if !(start_btn.is_connected("pressed",start_game)):
			start_btn.pressed.connect(start_game)
		print("I am a client (peer) %s" % str(LobbyManager.players.keys().find(multiplayer.get_unique_id())))
	if ready and LobbyManager.players.keys().find(multiplayer.get_unique_id()) == 0:
		start_btn.visible = true
	else:
		start_btn.visible = false

func start_game() -> void:
	print("Start game pressed by %s" % LobbyManager.players[multiplayer.get_unique_id()]["Name"])
	
