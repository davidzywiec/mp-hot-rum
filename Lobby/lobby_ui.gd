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
var is_host := false

var countdown_connection_done := false
@export var next_scene_fallback: String = "res://Menu/main_menu.tscn" # used only if server sends same


func _ready() -> void:
	set_ui_actions(false)
	ready_btn.pressed.connect(set_ready_flag)
	start_btn.pressed.connect(start_game)
	SignalManager.host_changed.connect(_on_host_changed)
	Game_State_Manager.player_state_updated.connect(update_lobby_ui)

	# Force one update using latest known state
	if Game_State_Manager.latest_player_state.size() > 0:
		update_lobby_ui(Game_State_Manager.latest_player_state)
	
	if not countdown_connection_done:
		# 1) Legacy bool path (kept)
		Game_State_Manager.countdown_toggle.connect(toggle_countdown_timer)
		# 2) Synced end time (new)
		Game_State_Manager.countdown_sync.connect(_on_countdown_sync)
		# 3) Scene change broadcast
		SignalManager.change_scene.connect(_on_change_scene)
		countdown_connection_done = true
	
func set_ready_flag() -> void:
	ready_status = !ready_status
	SignalManager.player_ready.emit(ready_status)
	if Network_Manager.handler is ClientHandler:
		var peer_id = multiplayer.get_unique_id()
		Network_Manager.handler.broadcast_ready_flag(peer_id, ready_status)
	
func set_ready_connection(card: PlayerCard) -> void:
	SignalManager.player_ready.connect(card.set_ready)

func set_ui_actions(all_ready: bool) -> void:
	if is_host and all_ready:
		start_btn.visible = true
		
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
	var all_ready : bool = false
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
		if i == 0 and player_info.peer_id == multiplayer.get_unique_id():
			all_ready = true

		if !player_info.ready:
			all_ready = false
	if players_data.size() < 2:
			all_ready = false
	# Show/hide buttons based on your role and readiness
	set_ui_actions(all_ready)

func start_game() -> void:
	SignalManager.toggle_game_countdown.emit(true)
	if Network_Manager.handler is ClientHandler:
		var peer_id = multiplayer.get_unique_id()
	# NetworkManager facade already forwards to the server:
	Network_Manager.rpc_id(1, "register_countdown", multiplayer.get_unique_id(), true)

# NEW: receives absolute end timestamp from server
func _on_countdown_sync(end_unix: int) -> void:
	# Compute remaining seconds from local system clock
	var now := Time.get_unix_time_from_system()
	var remaining : float = max(0, end_unix - now)
	if remaining <= 0:
		return
	# (Re)configure and start your label timer with precise remaining time
	if not label_timer.get_parent():
		add_child(label_timer)
	label_timer.configure("Game starting in... ", float(remaining))
	label_timer.start_timer()

# EXISTING path (bool) still works — we keep it as a fallback for manual starts/cancels
func toggle_countdown_timer(flag: bool) -> void:
	if flag:
		if not label_timer.get_parent():
			add_child(label_timer)
		label_timer.configure("Game starting in... ", 10.0) # will be overridden by _on_countdown_sync if broadcast arrives
		label_timer.start_timer()
		ready_btn.disabled = true
		start_btn.disabled = true
	else:
		if label_timer.get_parent():
			label_timer.stop_timer()
			remove_child(label_timer)
			ready_btn.disabled = false
			start_btn.disabled = false

# NEW: react to server-ordered scene change
func _on_change_scene(path: String) -> void:
	var target := path if path != "" else next_scene_fallback
	print("🎬 Changing scene to: ", target)
	get_tree().change_scene_to_file(target)

func _on_host_changed(host_peer_id: int) -> void:
	var me := multiplayer.get_unique_id()
	is_host = (me == host_peer_id)
	
