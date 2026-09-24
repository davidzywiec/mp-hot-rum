extends SceneTree

const TIMEOUT_SECONDS: float = 10.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	while current_scene == null:
		await process_frame
	var menu: Control = current_scene.get_node("MainMenu")
	menu.get_node("MarginContainer/VBoxContainer/UserName").text = "FirstHost"
	menu.join_server()
	var deadline: float = Time.get_unix_time_from_system() + TIMEOUT_SECONDS
	while Time.get_unix_time_from_system() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/lobby/lobby_ui.tscn":
			await process_frame
			var ai_controls: Control = current_scene.get_node("VBC/AIControls")
			if not ai_controls.visible:
				_fail("first Host cannot see Add AI Player after Lobby admission")
				return
			print("[AI_HOST_LOBBY_CLIENT_TEST][PASS]")
			quit(0)
			return
	_fail("first Host did not enter Lobby")

func _fail(message: String) -> void:
	printerr("[AI_HOST_LOBBY_CLIENT_TEST][FAIL] %s" % message)
	quit(1)
