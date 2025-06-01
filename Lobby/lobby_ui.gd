extends Control

@onready
var player_container = $GridContainer
@onready
var player_card = preload("res://Lobby/player_card.tscn")
@onready
var ready_btn = $VBC/ReadyButton
@onready
var start_btn = $VBC/StartButton

var label_timer_scene = preload("res://Utility/Timer/CountdownLabelTimer.tscn")
var label_timer = label_timer_scene.instantiate()

var ready_status: bool = false

func _ready() -> void:
	set_ui_actions(false)
	ready_btn.pressed.connect(set_ready_flag)
	start_btn.pressed.connect(start_game)
	Game_State_Manager.player_state_updated.connect(update_lobby_ui)

	# Force one update using latest known state
	if Game_State_Manager.latest_player_state.size() > 0:
		update_lobby_ui(Game_State_Manager.latest_player_state)
	
func set_ready_flag() -> void:
	ready_status = !ready_status
	SignalManager.player_ready.emit(ready_status)
	if Network_Manager.handler is ClientHandler:
		var peer_id = multiplayer.get_unique_id()
		Network_Manager.handler.broadcast_ready_flag(peer_id, ready_status)
	
func set_ready_connection(card: PlayerCard) -> void:
	SignalManager.player_ready.connect(card.set_ready)

func set_ui_actions(all_ready: bool) -> void:
	if multiplayer.is_server():
		start_btn.visible = false
		start_btn.disabled = true
		ready_btn.visible = false
		ready_btn.disabled = true
	else:
		start_btn.visible = all_ready
		start_btn.disabled = !all_ready
		ready_btn.visible = true
		ready_btn.disabled = false
		
func update_lobby_ui(players_data: Array) -> void:
	# Clear current player cards
	for node in player_container.get_children():
		node.queue_free()

	# Track if all players are ready
	var all_ready : bool = true
	var is_host : bool = false
	var my_id : int = multiplayer.get_unique_id()

	# Add players and check host/ready status
	for i in range(players_data.size()):
		var player_info = players_data[i]
		var card = player_card.instantiate()
		player_container.add_child(card)
		card.set_username(player_info.name)
		card.set_ready(player_info.ready)
		if player_info.peer_id == my_id:
			set_ready_connection(card)

		if !player_info.ready:
			all_ready = false

	# Show/hide buttons based on your role and readiness
	set_ui_actions(all_ready)

func start_game() -> void:
	# Configure it before adding to the scene
	label_timer.configure("Game starting in... ", 10.0)
	# Add to scene
	add_child(label_timer)
	# Start the timer
	label_timer.start_timer()
