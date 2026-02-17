@tool
extends Node

const DEBUG_SETTING_PATH: String = "debug/dev_overlay"

var _layer: CanvasLayer
var _label: Label
var _timer: Timer

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if DisplayServer.get_name() == "headless":
		return
	if not ProjectSettings.get_setting(DEBUG_SETTING_PATH, false):
		return
	_setup_overlay()

func _exit_tree() -> void:
	if _timer:
		_timer.stop()
		_timer.queue_free()
		_timer = null
	if _layer:
		_layer.queue_free()
		_layer = null

func _setup_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 99
	add_child(_layer)
	_label = Label.new()
	_label.text = "Dev Overlay"
	_label.position = Vector2(8, 8)
	_label.modulate = Color(1, 1, 1, 0.9)
	_layer.add_child(_label)
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.one_shot = false
	_timer.autostart = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	_refresh()

func _refresh() -> void:
	if _label == null:
		return
	var tree: SceneTree = get_tree()
	var scene_name: String = "<none>"
	if tree.current_scene != null:
		scene_name = tree.current_scene.name
	var peer_id: int = multiplayer.get_unique_id()
	var peers: PackedInt32Array = multiplayer.get_peers()
	var is_server: bool = multiplayer.is_server() or OS.has_feature("server")
	_label.text = "Dev Overlay\nScene: %s\nPeer: %s\nPeers: %s\nServer: %s" % [
		scene_name,
		str(peer_id),
		str(peers),
		str(is_server)
	]
