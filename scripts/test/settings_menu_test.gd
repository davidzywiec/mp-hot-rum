extends SceneTree

var _original_volume: float = 1.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var game_manager: Node = root.get_node("GameManager")
	var ruleset: Ruleset = Ruleset.new()
	var first_round: RoundRequirement = RoundRequirement.new()
	first_round.game_round = 1
	first_round.deal_count = 7
	first_round.sets_of_3 = 2
	var second_round: RoundRequirement = RoundRequirement.new()
	second_round.game_round = 2
	second_round.deal_count = 8
	second_round.sets_of_3 = 1
	second_round.runs_of_4 = 1
	ruleset.round_requirements = [first_round, second_round]
	game_manager.ruleset = ruleset
	game_manager.round_requirements_data = game_manager.serialize_round_requirements()
	var player_settings: Node = root.get_node("PlayerSettings")
	_original_volume = float(player_settings.call("get_master_volume"))
	var game_ui_scene: PackedScene = load("res://scenes/game/GameUI.tscn") as PackedScene
	var game_ui: Control = game_ui_scene.instantiate() as Control
	root.add_child(game_ui)
	await process_frame

	var menu_button: Button = game_ui.get_node_or_null("SettingsButton") as Button
	if menu_button == null:
		_fail("Expected an in-game settings button in the top-right corner.")
		return
	menu_button.pressed.emit()
	await process_frame
	var overlay: Control = game_ui.get_node_or_null("SettingsOverlay") as Control
	if overlay == null or not overlay.visible:
		_fail("Expected the settings menu to open from its button.")
		return
	if not _visible_text(overlay).contains("Round 1") or not _visible_text(overlay).contains("Round 2"):
		_fail("Expected the settings menu to show rules for every configured Round.")
		return

	var volume_slider: HSlider = game_ui.get_node_or_null("SettingsOverlay/Center/Panel/Margin/Content/SoundRow/VolumeSlider") as HSlider
	if volume_slider == null:
		_fail("Expected a sound volume control in the settings menu.")
		return
	volume_slider.value = 42.0
	if not is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.42):
		_fail("Expected changing the sound control to update the Master bus immediately.")
		return
	await create_timer(0.35).timeout
	var persisted_settings: ConfigFile = ConfigFile.new()
	if persisted_settings.load("user://settings.cfg") != OK or not is_equal_approx(float(persisted_settings.get_value("audio", "master_volume", -1.0)), 0.42):
		_fail("Expected the sound level to persist for the player.")
		return

	var close_button: Button = game_ui.get_node_or_null("SettingsOverlay/Center/Panel/Margin/Content/Header/CloseButton") as Button
	if close_button == null:
		_fail("Expected a close button in the settings menu.")
		return
	close_button.pressed.emit()
	await process_frame
	if overlay.visible:
		_fail("Expected the settings menu to close from its close button.")
		return
	var escape_event: InputEventKey = InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	Input.parse_input_event(escape_event)
	await process_frame
	if not overlay.visible:
		_fail("Expected Escape to open the settings menu during a Game.")
		return
	Input.parse_input_event(escape_event)
	await process_frame
	if overlay.visible:
		_fail("Expected Escape to close the settings menu during a Game.")
		return

	menu_button.pressed.emit()
	await process_frame
	var quit_button: Button = game_ui.get_node_or_null("SettingsOverlay/Center/Panel/Margin/Content/QuitButton") as Button
	if quit_button == null:
		_fail("Expected a Quit button in the settings menu.")
		return
	quit_button.pressed.emit()
	await process_frame
	await process_frame
	player_settings.call("set_master_volume", _original_volume)
	await create_timer(0.35).timeout
	if current_scene == null or current_scene.scene_file_path != "res://scenes/menu/main_menu.tscn":
		_fail("Expected Quit to return to the main menu.")
		return

	print("[SETTINGS_MENU_TEST][PASS]")
	quit(0)

func _visible_text(node: Node) -> String:
	var result: String = ""
	if node is Label:
		result += (node as Label).text + "\n"
	for child in node.get_children():
		result += _visible_text(child)
	return result

func _fail(message: String) -> void:
	printerr("[SETTINGS_MENU_TEST][FAIL] %s" % message)
	var player_settings: Node = root.get_node_or_null("PlayerSettings")
	if player_settings != null:
		player_settings.call("set_master_volume", _original_volume)
		await create_timer(0.35).timeout
	quit(1)
