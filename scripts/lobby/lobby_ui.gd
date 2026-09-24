extends Control

@onready
var player_container: GridContainer = $GridContainer
@onready
var player_card: PackedScene = preload("res://scenes/lobby/player_card.tscn")
@onready
var ready_btn: Button = $VBC/ReadyButton
@onready
var start_btn: Button = $VBC/StartButton
@onready var ai_controls: HBoxContainer = $VBC/AIControls
@onready var ai_difficulty_select: OptionButton = $VBC/AIControls/DifficultySelect
@onready var add_ai_button: Button = $VBC/AIControls/AddAIButton
@onready var ai_list: VBoxContainer = $VBC/AIList
@onready var lobby_error: Label = $VBC/LobbyError


var label_timer_scene: PackedScene = preload("res://scenes/utility/CountdownLabelTimer.tscn")
var label_timer: Node = label_timer_scene.instantiate()
var ready_status: bool = false
var is_host: bool = false
var roster_locked: bool = false
const MORNING_DIGEST_THEME: Theme = preload("res://Themes/GameUI.tres")
const MDTheme: GDScript = preload("res://scripts/ui/morning_digest_theme.gd")
const AI_PLAYER_DECISION_SCRIPT: GDScript = preload("res://scripts/ai/AIPlayerDecision.gd")

var countdown_connection_done: bool = false
@export var next_scene_fallback: String = "res://scenes/menu/main_menu.tscn" # used only if server sends same


func _ready() -> void:
	theme = MORNING_DIGEST_THEME
	_apply_card_button_theme_to_tree(self)
	set_ui_actions(false)
	_update_ready_button_label()
	ready_btn.pressed.connect(set_ready_flag)
	start_btn.pressed.connect(start_game)
	for difficulty in AI_PLAYER_DECISION_SCRIPT.DIFFICULTIES:
		ai_difficulty_select.add_item(difficulty)
	add_ai_button.pressed.connect(_on_add_ai_pressed)
	SignalManager.host_changed.connect(_on_host_changed)
	Game_State_Manager.player_state_updated.connect(update_lobby_ui)
	Game_State_Manager.game_state_updated.connect(_on_game_state_updated)
	Game_State_Manager.lobby_error.connect(_on_lobby_error)
	if Game_State_Manager.latest_host_peer_id != -1:
		_on_host_changed(Game_State_Manager.latest_host_peer_id)

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
	_update_ready_button_label()
	SignalManager.player_ready.emit(ready_status)
	if Network_Manager.handler is ClientHandler:
		var peer_id: int = multiplayer.get_unique_id()
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
		start_btn.visible = is_host
		start_btn.disabled = not all_ready or roster_locked
		ready_btn.visible = true
		ready_btn.disabled = roster_locked
	ai_controls.visible = is_host and not roster_locked and not multiplayer.is_server()
	add_ai_button.disabled = Game_State_Manager.latest_player_state.size() >= 6
	
		
func update_lobby_ui(players_data: Array) -> void:
	# Clear current player cards
	for node in player_container.get_children():
		node.queue_free()

	# Track if all players are ready
	var all_ready : bool = players_data.size() >= 2
	var my_id : int = multiplayer.get_unique_id()

	# Add players and check host/ready status
	for i in range(players_data.size()):
		var player_info: Variant = players_data[i]
		var card: PlayerCard = player_card.instantiate() as PlayerCard
		player_container.add_child(card)
		card.set_username(str(player_info.name))
		card.set_ready(player_info.ready)
		if player_info.peer_id == my_id:
			ready_status = player_info.ready
			_update_ready_button_label()
			set_ready_connection(card)
		if !player_info.ready:
			all_ready = false
	# Show/hide buttons based on your role and readiness
	set_ui_actions(all_ready)
	_rebuild_ai_rows(players_data)

func _rebuild_ai_rows(players_data: Array) -> void:
	for child in ai_list.get_children():
		child.queue_free()
	for raw_player in players_data:
		if not bool(raw_player.get("is_ai", false)):
			continue
		var ai_peer_id: int = int(raw_player.get("peer_id", 0))
		var row: HBoxContainer = HBoxContainer.new()
		ai_list.add_child(row)
		var name_label: Label = Label.new()
		name_label.text = str(raw_player.get("name", "AI Player"))
		row.add_child(name_label)
		if not is_host or roster_locked:
			continue
		var difficulty_select: OptionButton = OptionButton.new()
		for difficulty in AI_PLAYER_DECISION_SCRIPT.DIFFICULTIES:
			difficulty_select.add_item(difficulty)
		var current_difficulty: String = str(raw_player.get("difficulty", "Easy"))
		for index in range(difficulty_select.item_count):
			if difficulty_select.get_item_text(index) == current_difficulty:
				difficulty_select.select(index)
		row.add_child(difficulty_select)
		difficulty_select.item_selected.connect(_on_ai_difficulty_selected.bind(ai_peer_id, difficulty_select))
		var remove_button: Button = Button.new()
		remove_button.text = "Remove"
		row.add_child(remove_button)
		remove_button.pressed.connect(_on_remove_ai_pressed.bind(ai_peer_id))

func _on_add_ai_pressed() -> void:
	Network_Manager.rpc_id(1, "register_add_ai_player", ai_difficulty_select.get_item_text(ai_difficulty_select.selected))

func _on_remove_ai_pressed(ai_peer_id: int) -> void:
	Network_Manager.rpc_id(1, "register_remove_ai_player", ai_peer_id)

func _on_ai_difficulty_selected(index: int, ai_peer_id: int, select: OptionButton) -> void:
	Network_Manager.rpc_id(1, "register_ai_difficulty", ai_peer_id, select.get_item_text(index))

func _on_lobby_error(message: String) -> void:
	lobby_error.text = message
	lobby_error.visible = true

func _on_game_state_updated(state: Dictionary) -> void:
	var new_locked: bool = bool(state.get("roster_locked", false))
	if new_locked != roster_locked:
		roster_locked = new_locked
		update_lobby_ui(Game_State_Manager.latest_player_state)

func start_game() -> void:
	SignalManager.toggle_game_countdown.emit(true)
	# NetworkManager facade already forwards to the server:
	Network_Manager.rpc_id(1, "register_countdown", multiplayer.get_unique_id(), true)

# NEW: receives absolute end timestamp from server
func _on_countdown_sync(end_unix: int) -> void:
	roster_locked = true
	update_lobby_ui(Game_State_Manager.latest_player_state)
	# Compute remaining seconds from local system clock
	var now: float = Time.get_unix_time_from_system()
	var remaining : float = maxf(0.0, float(end_unix) - now)
	if remaining <= 0:
		return
	# (Re)configure and start your label timer with precise remaining time
	if not label_timer.get_parent():
		add_child(label_timer)
	label_timer.configure("Game starting in... ", float(remaining))
	label_timer.start_timer()

# EXISTING path (bool) still works — we keep it as a fallback for manual starts/cancels
func toggle_countdown_timer(flag: bool) -> void:
	roster_locked = flag
	if flag:
		if not label_timer.get_parent():
			add_child(label_timer)
		var fallback: float = 10.0
		if ProjectSettings.get_setting("debug/short_countdown", false):
			fallback = 1.0
		label_timer.configure("Game starting in... ", fallback) # will be overridden by _on_countdown_sync if broadcast arrives
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
	var target: String = path if path != "" else next_scene_fallback
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if tree.current_scene != null and tree.current_scene.scene_file_path == target:
		return
	print("Changing scene to: ", target)
	tree.change_scene_to_file(target)

func _on_host_changed(host_peer_id: int) -> void:
	var me: int = multiplayer.get_unique_id()
	is_host = (me == host_peer_id)
	update_lobby_ui(Game_State_Manager.latest_player_state)

func _apply_card_button_theme_to_tree(root: Node) -> void:
	if root == null:
		return
	if root is Button:
		_style_card_button(root as Button)
	for child in root.get_children():
		_apply_card_button_theme_to_tree(child)

func _style_card_button(button: Button) -> void:
	if button == null:
		return
	MDTheme.apply_button(button, 13)

func _update_ready_button_label() -> void:
	if ready_btn == null:
		return
	ready_btn.text = "Not Ready" if ready_status else "Ready"
