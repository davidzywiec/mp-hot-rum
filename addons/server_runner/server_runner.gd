@tool
extends EditorPlugin

var _run_button: Button
var _stop_button: Button
var _server_pid: int = -1
var _status_label: Label
var _status_timer: Timer

func _enter_tree() -> void:
	_run_button = Button.new()
	_run_button.text = "Run Server"
	_run_button.tooltip_text = "Launch a headless dedicated server instance."
	_run_button.pressed.connect(_on_run_server_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _run_button)
	_stop_button = Button.new()
	_stop_button.text = "Stop Server"
	_stop_button.tooltip_text = "Stop the last launched server instance."
	_stop_button.disabled = true
	_stop_button.pressed.connect(_on_stop_server_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _stop_button)
	_status_label = Label.new()
	_status_label.text = "Server: stopped"
	add_control_to_container(CONTAINER_TOOLBAR, _status_label)
	_status_timer = Timer.new()
	_status_timer.wait_time = 1.0
	_status_timer.one_shot = false
	_status_timer.autostart = true
	_status_timer.timeout.connect(_refresh_status)
	add_child(_status_timer)

func _exit_tree() -> void:
	if _run_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _run_button)
		_run_button.queue_free()
		_run_button = null
	if _stop_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _stop_button)
		_stop_button.queue_free()
		_stop_button = null
	if _status_label:
		remove_control_from_container(CONTAINER_TOOLBAR, _status_label)
		_status_label.queue_free()
		_status_label = null
	if _status_timer:
		_status_timer.stop()
		_status_timer.queue_free()
		_status_timer = null

func _on_run_server_pressed() -> void:
	var exe: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://")
	var log_path: String = ProjectSettings.globalize_path("user://server.log")
	var args: PackedStringArray = PackedStringArray([
		"--headless",
		"--audio-driver",
		"Dummy",
		"--server",
		"--log-file",
		log_path,
		"--path",
		project_path
	])
	if ProjectSettings.get_setting("debug/short_countdown", false):
		args.append("--short-countdown")
	var pid: int = OS.create_process(exe, args)
	if pid <= 0:
		push_error("Failed to launch server process. Check editor executable path and permissions.")
	else:
		_server_pid = pid
		_stop_button.disabled = false
		print("Launched server process, pid:", pid)
		_refresh_status()

func _on_stop_server_pressed() -> void:
	if _server_pid <= 0:
		return
	if OS.is_process_running(_server_pid):
		OS.kill(_server_pid)
		print("Stopped server process, pid:", _server_pid)
	_server_pid = -1
	_stop_button.disabled = true
	_refresh_status()

func _refresh_status() -> void:
	if _status_label == null:
		return
	var running: bool = _server_pid > 0 and OS.is_process_running(_server_pid)
	_status_label.text = "Server: running" if running else "Server: stopped"
