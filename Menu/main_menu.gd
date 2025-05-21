extends Control

@onready
var host_btn : Button = $MarginContainer/VBoxContainer/HostBtn
@onready
var join_btn : Button = $MarginContainer/VBoxContainer/JoinBtn
@onready
var ip_line_edit : LineEdit = $MarginContainer/VBoxContainer/IPLine
@onready
var status_label : Label = $StatusLabel
@onready
var username_line_edit : LineEdit = $MarginContainer/VBoxContainer/UserName

@export
var lobby_scene : PackedScene = preload("res://Lobby/lobby_ui.tscn")

func _ready() -> void:
	host_btn.pressed.connect(start_server)
	join_btn.pressed.connect(join_server)
	SignalManager.failed_connection.connect(connection_failed)
	SignalManager.player_connected.connect(connection_success)
	
func _process(delta: float) -> void:
	if username_line_edit.text.length() > 0:
		join_btn.disabled = false
	else:
		join_btn.disabled = true

func start_server():
	SignalManager.start_server.emit()
	status_label.text = "Started server..."
	if multiplayer.get_unique_id() == 1:
		get_tree().change_scene_to_packed(lobby_scene)
	
func join_server():
	if ip_line_edit.text:
		SignalManager.join_server.emit(ip_line_edit.text)
		status_label.text = "Connecting..."

func connection_failed() -> void:
	status_label.text = "Error connecting."

func connection_success(user_id) -> void:
	status_label.text = "Connected!"
	SignalManager.register_username.emit(username_line_edit.text)
	get_tree().change_scene_to_packed(lobby_scene)
