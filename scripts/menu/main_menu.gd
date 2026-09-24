extends Control

# --- UI Node References ---
@onready var join_btn: Button = $MarginContainer/VBoxContainer/JoinBtn
@onready var ip_line_edit: LineEdit = $MarginContainer/VBoxContainer/IPLine
@onready var status_label: Label = $StatusLabel
@onready var username_line_edit: LineEdit = $MarginContainer/VBoxContainer/UserName

# --- Lobby Scene to Load After Successful Connection ---
@export var lobby_scene: PackedScene = preload("res://scenes/lobby/lobby_ui.tscn")

const MORNING_DIGEST_THEME: Theme = preload("res://Themes/GameUI.tres")
const MDTheme: GDScript = preload("res://scripts/ui/morning_digest_theme.gd")

func _ready() -> void:
	theme = MORNING_DIGEST_THEME
	_apply_card_button_theme_to_tree(self)
	_apply_line_edit_theme_to_tree(self)
	# Connect UI buttons to their handlers
	join_btn.pressed.connect(join_server)

	# Connect to signals emitted by networking logic
	SignalManager.failed_connection.connect(connection_failed)
	SignalManager.server_connected.connect(connection_success)
	Game_State_Manager.lobby_admission_result.connect(_on_lobby_admission_result)

	# Initialize status label to be hidden and empty
	status_label.text = ""
	status_label.visible = false
	status_label.add_theme_color_override("font_color", MDTheme.TEXT_PRIMARY)
	status_label.add_theme_font_size_override("font_size", 18)

func _process(_delta: float) -> void:
	# Disable the Join button if the username field is empty or only spaces
	join_btn.disabled = username_line_edit.text.strip_edges().is_empty()

# --- Called when the Join button is pressed ---
func join_server():
	var ip: String = ip_line_edit.text.strip_edges()
	var username: String = username_line_edit.text.strip_edges()

	# Validate input before trying to connect
	if ip and username:
		status_label.text = "Connecting..."
		status_label.visible = true
		Network_Manager.join_server(ip)
	else:
		status_label.text = "Please enter both username and IP address."
		status_label.visible = true

# --- Triggered when connection fails (from ClientHandler) ---
func connection_failed():
	if not status_label.text.contains("Lobby full"):
		status_label.text = "❌ Error connecting."
	status_label.visible = true

# --- Triggered on successful connection (from ClientHandler or server peer registration) ---
func connection_success(_user_id = null):
	status_label.text = "Joining Lobby..."
	status_label.visible = true

	# Send the username to the server for player registration
	Network_Manager.rpc_id(1, "register_player", username_line_edit.text.strip_edges(), multiplayer.get_unique_id())
	print("Emitting username:", username_line_edit.text)


func _on_lobby_admission_result(accepted: bool, reason: String) -> void:
	if not accepted:
		status_label.text = reason if not reason.is_empty() else "Could not join Lobby."
		status_label.visible = true
		return
	status_label.text = "✅ Connected!"
	change_to_lobby()

# --- Helper to change scenes to the main lobby UI ---
func change_to_lobby():
	get_tree().change_scene_to_packed(lobby_scene)

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
	MDTheme.apply_button(button, 18)

func _apply_line_edit_theme_to_tree(root: Node) -> void:
	if root == null:
		return
	if root is LineEdit:
		_style_line_edit(root as LineEdit)
	for child in root.get_children():
		_apply_line_edit_theme_to_tree(child)

func _style_line_edit(line_edit: LineEdit) -> void:
	if line_edit == null:
		return
	MDTheme.apply_line_edit(line_edit, 20)
	line_edit.custom_minimum_size = Vector2(maxf(line_edit.custom_minimum_size.x, 320.0), 44.0)
