extends Control

# --- UI Node References ---
@onready var host_btn: Button = $MarginContainer/VBoxContainer/HostBtn
@onready var join_btn: Button = $MarginContainer/VBoxContainer/JoinBtn
@onready var ip_line_edit: LineEdit = $MarginContainer/VBoxContainer/IPLine
@onready var status_label: Label = $StatusLabel
@onready var username_line_edit: LineEdit = $MarginContainer/VBoxContainer/UserName

# --- Lobby Scene to Load After Successful Connection ---
@export var lobby_scene: PackedScene = preload("res://scenes/lobby/lobby_ui.tscn")

func _ready() -> void:
	# Connect UI buttons to their handlers
	host_btn.pressed.connect(start_server)
	join_btn.pressed.connect(join_server)

	# Connect to signals emitted by networking logic
	SignalManager.failed_connection.connect(connection_failed)
	SignalManager.server_connected.connect(connection_success)
	SignalManager.player_connected.connect(connection_success)

	# Initialize status label to be hidden and empty
	status_label.text = ""
	status_label.visible = false

func _process(delta: float) -> void:
	# Disable the Join button if the username field is empty or only spaces
	join_btn.disabled = username_line_edit.text.strip_edges().is_empty()

# --- Called when the Host button is pressed ---
func start_server():
	# Start the ENet server using NetworkManager (Facade)
	Network_Manager.start_server()

	# If we're the host (ID 1), immediately go to the lobby scene
	if multiplayer.get_unique_id() == 1:
		change_to_lobby()

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
