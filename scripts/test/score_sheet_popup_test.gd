extends Node

const GAME_UI_SCENE: PackedScene = preload("res://scenes/game/GameUI.tscn")

func _ready() -> void:
	call_deferred("_run_and_quit")

func _run_and_quit() -> void:
	await get_tree().process_frame
	_setup_latest_round_score()
	var game_ui: Control = GAME_UI_SCENE.instantiate() as Control
	get_tree().root.add_child(game_ui)
	await get_tree().process_frame

	var score_sheet_button: Button = game_ui.get_node_or_null(
		"RoundDataContainer/BottomControlsBar/ActionBar/ScoreSheetButton"
	) as Button
	if score_sheet_button == null:
		_fail("Expected the Score Sheet button to be available.")
		return
	score_sheet_button.pressed.emit()
	await get_tree().process_frame

	var score_sheet: AcceptDialog = _find_score_sheet_popup(game_ui)
	if score_sheet == null:
		_fail("Expected Score Sheet to open after its button is pressed.")
		return
	var visible_text: String = _visible_text(score_sheet)
	if not visible_text.contains("Round Leader - Ada"):
		_fail("Expected Score Sheet to show the latest round leader.")
		return
	if not visible_text.contains("12 pts total"):
		_fail("Expected Score Sheet to show the leader total.")
		return
	if not visible_text.contains("Points this round") or not visible_text.contains("Total Points"):
		_fail("Expected Score Sheet to show the End of Round score table headers.")
		return
	if not visible_text.contains("Ada") or not visible_text.contains("Bea"):
		_fail("Expected Score Sheet to show each player from the latest completed Round.")
		return
	if visible_text.contains("Cora"):
		_fail("Score Sheet must not display scores from earlier Rounds.")
		return
	if visible_text.contains("Ready for next round") or visible_text.contains("Next Round"):
		_fail("Score Sheet must not expose End of Round continuation controls.")
		return
	game_ui.queue_free()
	await get_tree().process_frame

	_setup_empty_score_sheet()
	var empty_game_ui: Control = GAME_UI_SCENE.instantiate() as Control
	get_tree().root.add_child(empty_game_ui)
	await get_tree().process_frame
	var empty_score_sheet_button: Button = empty_game_ui.get_node_or_null(
		"RoundDataContainer/BottomControlsBar/ActionBar/ScoreSheetButton"
	) as Button
	if empty_score_sheet_button == null:
		_fail("Expected the Score Sheet button to be available before any Round completes.")
		return
	empty_score_sheet_button.pressed.emit()
	await get_tree().process_frame
	var empty_score_sheet: AcceptDialog = _find_score_sheet_popup(empty_game_ui)
	if empty_score_sheet == null:
		_fail("Expected Score Sheet to open before any Round completes.")
		return
	if not _visible_text(empty_score_sheet).contains("No completed Rounds yet."):
		_fail("Expected Score Sheet to explain when no Round has completed.")
		return

	print("[SCORE_SHEET_POPUP_TEST][PASS]")
	get_tree().quit(0)

func _setup_latest_round_score() -> void:
	var game_manager: Node = get_tree().root.get_node_or_null("GameManager")
	if game_manager == null:
		_fail("GameManager autoload not found.")
		return
	game_manager.end_game_session()
	game_manager.players.clear()
	game_manager.player_order.clear()
	game_manager.score_sheet_data.clear()
	game_manager.latest_round_score_data = {
		"round": 3,
		"rows": [
			{"peer_id": 1, "name": "Ada", "round_points": 5, "total_points": 12},
			{"peer_id": 2, "name": "Bea", "round_points": 8, "total_points": 20}
		]
	}
	game_manager.score_sheet_data.append({
		"round": 2,
		"rows": [
			{"peer_id": 3, "name": "Cora", "round_points": 4, "total_points": 9}
		]
	})
	game_manager.score_sheet_data.append(game_manager.latest_round_score_data.duplicate(true))
	game_manager.round_number = 3
	game_manager.game_over = false
	game_manager.round_summary_pending = false

func _setup_empty_score_sheet() -> void:
	var game_manager: Node = get_tree().root.get_node_or_null("GameManager")
	if game_manager == null:
		_fail("GameManager autoload not found.")
		return
	game_manager.score_sheet_data.clear()
	game_manager.latest_round_score_data.clear()
	game_manager.round_number = 1
	game_manager.game_over = false
	game_manager.round_summary_pending = false

func _find_score_sheet_popup(game_ui: Control) -> AcceptDialog:
	for child in game_ui.get_children():
		if child is AcceptDialog and (child as AcceptDialog).title == "Score Sheet":
			return child as AcceptDialog
	return null

func _visible_text(node: Node) -> String:
	var text: String = ""
	if node is Label:
		text += (node as Label).text + "\n"
	elif node is RichTextLabel:
		text += (node as RichTextLabel).get_parsed_text() + "\n"
	for child in node.get_children():
		text += _visible_text(child)
	return text

func _fail(message: String) -> void:
	printerr("[SCORE_SHEET_POPUP_TEST][FAIL] %s" % message)
	get_tree().quit(1)
