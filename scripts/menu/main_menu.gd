extends Control

# --- UI Node References ---
@onready var join_btn: Button = $MarginContainer/VBoxContainer/JoinBtn
@onready var ip_line_edit: LineEdit = $MarginContainer/VBoxContainer/IPLine
@onready var status_label: Label = $StatusLabel
@onready var username_line_edit: LineEdit = $MarginContainer/VBoxContainer/UserName

# --- Lobby Scene to Load After Successful Connection ---
@export var lobby_scene: PackedScene = preload("res://scenes/lobby/lobby_ui.tscn")

var _button_style_normal: StyleBoxFlat = null
var _button_style_hover: StyleBoxFlat = null
var _button_style_pressed: StyleBoxFlat = null
var _button_style_disabled: StyleBoxFlat = null
var _input_style_normal: StyleBoxFlat = null
var _input_style_focus: StyleBoxFlat = null
var _input_style_readonly: StyleBoxFlat = null

func _ready() -> void:
	_apply_card_button_theme_to_tree(self)
	_apply_line_edit_theme_to_tree(self)
	# Connect UI buttons to their handlers
	join_btn.pressed.connect(join_server)

	# Connect to signals emitted by networking logic
	SignalManager.failed_connection.connect(connection_failed)
	SignalManager.server_connected.connect(connection_success)
	SignalManager.player_connected.connect(connection_success)

	# Initialize status label to be hidden and empty
	status_label.text = ""
	status_label.visible = false
	status_label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98, 1.0))
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
	status_label.text = "❌ Error connecting."
	status_label.visible = true

# --- Triggered on successful connection (from ClientHandler or server peer registration) ---
func connection_success(_user_id = null):
	status_label.text = "✅ Connected!"
	status_label.visible = true

	# Send the username to the server for player registration
	Network_Manager.rpc_id(1, "register_player", username_line_edit.text.strip_edges(), multiplayer.get_unique_id())
	print("Emitting username:", username_line_edit.text)

	# Load the lobby scene
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
	_ensure_card_button_styles()
	button.add_theme_stylebox_override("normal", _button_style_normal)
	button.add_theme_stylebox_override("hover", _button_style_hover)
	button.add_theme_stylebox_override("pressed", _button_style_pressed)
	button.add_theme_stylebox_override("focus", _button_style_hover)
	button.add_theme_stylebox_override("disabled", _button_style_disabled)
	button.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.98, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.56, 0.62, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.98, 0.99, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 18)

func _ensure_card_button_styles() -> void:
	if _button_style_normal != null:
		return
	_button_style_normal = _make_button_style(
		Color(0.102, 0.157, 0.239, 0.94),
		Color(0.168, 0.227, 0.329, 1.0)
	)
	_button_style_hover = _make_button_style(
		Color(0.125, 0.188, 0.286, 0.97),
		Color(0.235, 0.313, 0.447, 1.0)
	)
	_button_style_pressed = _make_button_style(
		Color(0.082, 0.129, 0.204, 1.0),
		Color(0.219, 0.298, 0.431, 1.0)
	)
	_button_style_disabled = _make_button_style(
		Color(0.090, 0.110, 0.145, 0.88),
		Color(0.148, 0.168, 0.211, 0.9)
	)

func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 12
	style.content_margin_top = 7
	style.content_margin_right = 12
	style.content_margin_bottom = 7
	return style

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
	_ensure_input_styles()
	line_edit.add_theme_stylebox_override("normal", _input_style_normal)
	line_edit.add_theme_stylebox_override("focus", _input_style_focus)
	line_edit.add_theme_stylebox_override("read_only", _input_style_readonly)
	line_edit.add_theme_color_override("font_color", Color(0.95, 0.97, 0.99, 1.0))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.66, 0.71, 0.79, 1.0))
	line_edit.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	line_edit.add_theme_color_override("selection_color", Color(0.22, 0.39, 0.67, 0.85))
	line_edit.add_theme_color_override("caret_color", Color(0.90, 0.94, 1.0, 1.0))
	line_edit.add_theme_font_size_override("font_size", 20)
	line_edit.custom_minimum_size = Vector2(maxf(line_edit.custom_minimum_size.x, 320.0), 44.0)

func _ensure_input_styles() -> void:
	if _input_style_normal != null:
		return
	_input_style_normal = _make_input_style(
		Color(0.090, 0.120, 0.180, 0.95),
		Color(0.168, 0.227, 0.329, 1.0)
	)
	_input_style_focus = _make_input_style(
		Color(0.100, 0.138, 0.212, 0.98),
		Color(0.30, 0.46, 0.72, 1.0)
	)
	_input_style_readonly = _make_input_style(
		Color(0.085, 0.102, 0.145, 0.90),
		Color(0.148, 0.168, 0.211, 0.95)
	)

func _make_input_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	return style
