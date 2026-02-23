extends Control

@onready var round_number_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/RoundNumberContainer/RoundNumber
@onready var current_player_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/CurrentPlayerContainer/CurrentPlayer

var hand_scroll: ScrollContainer = null
var hand_container: HBoxContainer = null
var hand_title: Label = null
var end_turn_button: Button = null
var pass_pile_button: Button = null
var claim_pile_button: Button = null
var meld_board_button: Button = null
var score_sheet_button: Button = null
var debug_end_game_button: Button = null
var put_down_button: Button = null
var discard_selected_button: Button = null
var clear_selection_button: Button = null
var claim_status_label: Label = null
var claim_popup: AcceptDialog = null
var put_down_error_popup: AcceptDialog = null
var staged_panel: PanelContainer = null
var staged_title_label: Label = null
var staged_scroll: ScrollContainer = null
var staged_container: HBoxContainer = null
var pile_title_label: Label = null
var pile_card_holder: CenterContainer = null
var pile_card_view: CardView = null
var round_rules_label: Label = null
var turn_pickup_overlay: ColorRect = null
var turn_pickup_title_label: Label = null
var turn_pickup_status_label: Label = null
var turn_pickup_deck_button: Button = null
var turn_pickup_discard_button: Button = null
var game_over_overlay: ColorRect = null
var game_over_title_label: Label = null
var game_over_status_label: Label = null
var game_over_scores_text: RichTextLabel = null
var play_again_game_button: Button = null
var leave_game_button: Button = null

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/game/CardView.tscn")
const BASE_HAND_SPACING: float = 4.0
const STAGED_CARD_SCALE: float = 0.55
const PILE_CARD_SCALE: float = 1.0
const TURN_DEBUG: bool = true
const PUT_DOWN_ERROR_DISPLAY_MS: int = 4500
const MAIN_MENU_SCENE_PATH: String = "res://scenes/menu/main_menu.tscn"
const DEBUG_UI_SETTING_PATH: String = "debug/ui_debug"

var _dragging_card: CardView = null
var _drag_visual: CardView = null
var _drag_placeholder: PanelContainer = null
var _drag_mouse_offset: Vector2 = Vector2.ZERO
var _selected_cards: Array[CardView] = []
var _put_down_error_text: String = ""
var _put_down_error_until_msec: int = 0
var _meld_board_popup: AcceptDialog = null
var _meld_board_scroll: ScrollContainer = null
var _meld_board_list: VBoxContainer = null
var _score_sheet_popup: AcceptDialog = null
var _score_sheet_text: RichTextLabel = null
var _local_claim_offer_passed: bool = false
var _play_again_vote_peer_ids: Array[int] = []

func _ready() -> void:
	_resolve_hand_nodes()
	if end_turn_button != null:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if pass_pile_button != null:
		pass_pile_button.pressed.connect(_on_pass_pile_pressed)
	if claim_pile_button != null:
		claim_pile_button.pressed.connect(_on_claim_pile_pressed)
	if meld_board_button != null:
		meld_board_button.pressed.connect(_on_meld_board_pressed)
	if score_sheet_button != null:
		score_sheet_button.pressed.connect(_on_score_sheet_pressed)
	if debug_end_game_button != null:
		debug_end_game_button.pressed.connect(_on_debug_end_game_pressed)
	if put_down_button != null:
		put_down_button.pressed.connect(_on_put_down_pressed)
	if discard_selected_button != null:
		discard_selected_button.pressed.connect(_on_discard_selected_pressed)
	if clear_selection_button != null:
		clear_selection_button.pressed.connect(_on_clear_selection_pressed)
	if turn_pickup_deck_button != null:
		turn_pickup_deck_button.pressed.connect(_on_turn_pickup_deck_pressed)
	if turn_pickup_discard_button != null:
		turn_pickup_discard_button.pressed.connect(_on_turn_pickup_discard_pressed)
	if play_again_game_button != null:
		play_again_game_button.pressed.connect(_on_play_again_game_pressed)
	if leave_game_button != null:
		leave_game_button.pressed.connect(_on_leave_game_pressed)
	_update_end_turn_button_state()
	_update_action_buttons_state()
	_update_claim_status_label()
	_refresh_meld_board_if_open()
	_update_pile_view()
	_update_round_rules_ui()
	_update_game_over_overlay()
	_update_turn_pickup_overlay()
	_update_debug_controls_visibility()
	_debug_turn_state("ready")
	SignalManager.round_updated.connect(update_round_ui)
	Game_State_Manager.game_state_updated.connect(_on_game_state_updated)
	Game_State_Manager.private_hand_updated.connect(_on_private_hand_updated)
	Game_State_Manager.private_put_down_buffer_updated.connect(_on_private_put_down_buffer_updated)
	Game_State_Manager.pile_claimed_notification.connect(_on_pile_claimed_notification)
	Game_State_Manager.put_down_error.connect(_on_put_down_error)
	set_process(true)
	if multiplayer.is_server() or OS.has_feature("server"):
		pull_round_ui()
	_render_local_hand()

func _on_game_state_updated(state: Dictionary) -> void:
	_update_play_again_votes_from_state(state)
	if not GameManager.claim_window_active:
		_local_claim_offer_passed = false
	if not GameManager.game_over:
		_play_again_vote_peer_ids.clear()
	_debug_turn_state("game_state_updated_pre")
	pull_round_ui()
	_update_action_buttons_state()
	_update_claim_status_label()
	_update_pile_view()
	_update_round_rules_ui()
	_update_game_over_overlay()
	_update_turn_pickup_overlay()
	_update_staged_put_down_ui()
	_refresh_meld_board_if_open()
	_refresh_score_sheet_if_open()
	_debug_turn_state("game_state_updated_post")

func pull_round_ui() -> void:
	var round: int = GameManager.round_number
	var current_player_name: String = GameManager.get_player_name(GameManager.current_player_index)
	if GameManager.game_over:
		current_player_name = _game_over_status_text()
	update_round_ui(round, current_player_name)


func update_round_ui(round: int, current_player_name: String) -> void:
	print("Updating round UI: Round %d, Current Player: %s" % [round, current_player_name])
	round_number_label.clear()
	round_number_label.parse_bbcode("[b]Round: [/b]%d" % round)
	
	current_player_label.clear()
	current_player_label.parse_bbcode("[b]Current Player: [/b]%s" % current_player_name)
	_update_end_turn_button_state()
	_update_action_buttons_state()
	_update_claim_status_label()
	_update_pile_view()
	_update_round_rules_ui()
	_update_game_over_overlay()
	_update_turn_pickup_overlay()
	_refresh_score_sheet_if_open()
	_debug_turn_state("update_round_ui")

func _on_private_hand_updated(_cards: Array) -> void:
	_render_local_hand()
	_update_staged_put_down_ui()
	_refresh_meld_board_if_open()

func _on_private_put_down_buffer_updated(_cards_data: Array) -> void:
	_update_staged_put_down_ui()

func _render_local_hand() -> void:
	if not _ensure_hand_nodes():
		return
	_reset_drag_state()
	_clear_selected_cards(false)
	for child in hand_container.get_children():
		child.queue_free()
	var my_peer_id: int = multiplayer.get_unique_id()
	if not GameManager.player_hands.has(my_peer_id):
		hand_title.text = "Your Hand (0)"
		return
	var cards: Array = GameManager.player_hands[my_peer_id]
	hand_title.text = "Your Hand (%d)" % cards.size()
	for c in cards:
		if not (c is Card):
			continue
		var card_view: CardView = CARD_VIEW_SCENE.instantiate() as CardView
		if card_view == null:
			continue
		hand_container.add_child(card_view)
		card_view.set_card(c)
		card_view.apply_scale_ratio(1.0)
		card_view.gui_input.connect(_on_card_gui_input.bind(card_view))
	hand_container.add_theme_constant_override("separation", int(BASE_HAND_SPACING))
	if hand_scroll != null:
		hand_scroll.scroll_horizontal = 0
	_update_end_turn_button_state()
	_update_action_buttons_state()
	_update_claim_status_label()
	_update_pile_view()
	_update_round_rules_ui()
	_update_turn_pickup_overlay()
	_update_staged_put_down_ui()

func _on_card_gui_input(event: InputEvent, card_view: CardView) -> void:
	if _dragging_card != null:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed and mouse_button.shift_pressed:
			_toggle_selected_card(card_view)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_card_drag(card_view, mouse_button.global_position)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _dragging_card == null:
		return
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_card_drag(mouse_motion.global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_finish_card_drag(mouse_button.global_position)
			get_viewport().set_input_as_handled()

func _begin_card_drag(card_view: CardView, mouse_global: Vector2) -> void:
	if hand_container == null:
		return
	if card_view == null:
		return
	if card_view.get_parent() != hand_container:
		return
	_dragging_card = card_view
	_drag_mouse_offset = mouse_global - card_view.global_position

	var original_index: int = card_view.get_index()
	hand_container.remove_child(card_view)
	_create_drag_placeholder(card_view)
	hand_container.move_child(_drag_placeholder, original_index)
	_create_drag_visual(card_view)
	set_process_unhandled_input(true)
	_update_card_drag(mouse_global)

func _update_card_drag(mouse_global: Vector2) -> void:
	if _dragging_card == null:
		return
	if _drag_visual != null:
		_drag_visual.global_position = mouse_global - _drag_mouse_offset
	_move_placeholder_to_mouse(mouse_global.x)

func _finish_card_drag(mouse_global: Vector2) -> void:
	if _dragging_card == null:
		return
	_update_card_drag(mouse_global)

	var target_index: int = 0
	if _drag_placeholder != null and _drag_placeholder.get_parent() == hand_container:
		target_index = _drag_placeholder.get_index()
		hand_container.remove_child(_drag_placeholder)
		_drag_placeholder.queue_free()
	_drag_placeholder = null

	hand_container.add_child(_dragging_card)
	var clamped_index: int = clampi(target_index, 0, hand_container.get_child_count() - 1)
	hand_container.move_child(_dragging_card, clamped_index)

	if _drag_visual != null:
		_drag_visual.queue_free()
	_drag_visual = null
	_dragging_card = null
	_drag_mouse_offset = Vector2.ZERO
	set_process_unhandled_input(false)
	_apply_hand_order_to_game_state()

func _create_drag_visual(source_card: CardView) -> void:
	var drag_visual: CardView = CARD_VIEW_SCENE.instantiate() as CardView
	if drag_visual == null:
		return
	drag_visual.top_level = true
	drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_visual.z_index = 100
	drag_visual.modulate = Color(1.0, 1.0, 1.0, 0.78)
	drag_visual.set_card(source_card.get_card())
	drag_visual.apply_scale_ratio(1.0)
	add_child(drag_visual)
	_drag_visual = drag_visual

func _create_drag_placeholder(source_card: CardView) -> void:
	if hand_container == null:
		return
	var placeholder: PanelContainer = PanelContainer.new()
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.custom_minimum_size = source_card.get_combined_minimum_size()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.6, 1.0, 0.18)
	style.border_color = Color(0.35, 0.6, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	placeholder.add_theme_stylebox_override("panel", style)
	hand_container.add_child(placeholder)
	_drag_placeholder = placeholder

func _move_placeholder_to_mouse(mouse_global_x: float) -> void:
	if hand_container == null:
		return
	if _drag_placeholder == null:
		return
	if _drag_placeholder.get_parent() != hand_container:
		return

	hand_container.remove_child(_drag_placeholder)
	var target_index: int = hand_container.get_child_count()
	for i in range(hand_container.get_child_count()):
		var child: Node = hand_container.get_child(i)
		if not (child is Control):
			continue
		var child_control: Control = child as Control
		var center_x: float = child_control.global_position.x + (child_control.size.x * 0.5)
		if mouse_global_x < center_x:
			target_index = i
			break
	hand_container.add_child(_drag_placeholder)
	hand_container.move_child(_drag_placeholder, target_index)

func _apply_hand_order_to_game_state() -> void:
	if hand_container == null:
		return
	var my_peer_id: int = multiplayer.get_unique_id()
	if not GameManager.player_hands.has(my_peer_id):
		return
	var reordered_cards: Array[Card] = []
	var serialized_cards: Array = []
	for child in hand_container.get_children():
		if child is CardView:
			var card_view: CardView = child as CardView
			var card_data: Card = card_view.get_card()
			if card_data != null:
				reordered_cards.append(card_data)
				serialized_cards.append(card_data.to_dict())
	GameManager.player_hands[my_peer_id] = reordered_cards

	# Send reorder to authoritative server so order is persisted.
	if not multiplayer.is_server() and not OS.has_feature("server"):
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_hand_reorder", serialized_cards)

func _reset_drag_state() -> void:
	if _drag_visual != null:
		_drag_visual.queue_free()
	_drag_visual = null
	if _drag_placeholder != null:
		if hand_container != null and _drag_placeholder.get_parent() == hand_container:
			hand_container.remove_child(_drag_placeholder)
		_drag_placeholder.queue_free()
	_drag_placeholder = null
	if _dragging_card != null and _dragging_card.get_parent() == null:
		_dragging_card.queue_free()
	_dragging_card = null
	_drag_mouse_offset = Vector2.ZERO
	set_process_unhandled_input(false)

func _ensure_hand_nodes() -> bool:
	if hand_container != null and hand_title != null:
		return true
	_resolve_hand_nodes()
	return hand_container != null and hand_title != null

func _resolve_hand_nodes() -> void:
	var round_data: Node = get_node_or_null("RoundDataContainer")
	if round_data == null:
		return

	hand_title = get_node_or_null("RoundDataContainer/HandTitle") as Label
	end_turn_button = get_node_or_null("RoundDataContainer/EndTurnButton") as Button
	pass_pile_button = get_node_or_null("RoundDataContainer/ActionBar/PassPileButton") as Button
	claim_pile_button = get_node_or_null("RoundDataContainer/ActionBar/ClaimPileButton") as Button
	meld_board_button = get_node_or_null("RoundDataContainer/ActionBar/MeldBoardButton") as Button
	score_sheet_button = get_node_or_null("RoundDataContainer/ActionBar/ScoreSheetButton") as Button
	debug_end_game_button = get_node_or_null("RoundDataContainer/ActionBar/DebugEndGameButton") as Button
	put_down_button = get_node_or_null("RoundDataContainer/ActionBar/PutDownButton") as Button
	discard_selected_button = get_node_or_null("RoundDataContainer/ActionBar/DiscardSelectedButton") as Button
	clear_selection_button = get_node_or_null("RoundDataContainer/ActionBar/ClearSelectionButton") as Button
	claim_status_label = get_node_or_null("RoundDataContainer/ClaimStatusLabel") as Label
	staged_panel = get_node_or_null("RoundDataContainer/StagedAreaPanel") as PanelContainer
	staged_title_label = get_node_or_null("RoundDataContainer/StagedAreaPanel/VB/StagedAreaTitle") as Label
	staged_scroll = get_node_or_null("RoundDataContainer/StagedAreaPanel/VB/StagedAreaScroll") as ScrollContainer
	staged_container = get_node_or_null("RoundDataContainer/StagedAreaPanel/VB/StagedAreaScroll/StagedAreaContainer") as HBoxContainer
	pile_title_label = get_node_or_null("RoundDataContainer/PileContainer/PileTitle") as Label
	pile_card_holder = get_node_or_null("RoundDataContainer/PileContainer/PileCardHolder") as CenterContainer
	round_rules_label = get_node_or_null("RoundDataContainer/RoundRulesPanel/RoundRulesLabel") as Label
	turn_pickup_overlay = get_node_or_null("RoundDataContainer/TurnPickupOverlay") as ColorRect
	turn_pickup_title_label = get_node_or_null("RoundDataContainer/TurnPickupOverlay/Center/Panel/VB/TitleLabel") as Label
	turn_pickup_status_label = get_node_or_null("RoundDataContainer/TurnPickupOverlay/Center/Panel/VB/StatusLabel") as Label
	turn_pickup_deck_button = get_node_or_null("RoundDataContainer/TurnPickupOverlay/Center/Panel/VB/Buttons/PickupDeckButton") as Button
	turn_pickup_discard_button = get_node_or_null("RoundDataContainer/TurnPickupOverlay/Center/Panel/VB/Buttons/PickupDiscardButton") as Button
	game_over_overlay = get_node_or_null("RoundDataContainer/GameOverOverlay") as ColorRect
	game_over_title_label = get_node_or_null("RoundDataContainer/GameOverOverlay/Center/Panel/VB/TitleLabel") as Label
	game_over_status_label = get_node_or_null("RoundDataContainer/GameOverOverlay/Center/Panel/VB/StatusLabel") as Label
	game_over_scores_text = get_node_or_null("RoundDataContainer/GameOverOverlay/Center/Panel/VB/ScoresText") as RichTextLabel
	play_again_game_button = get_node_or_null("RoundDataContainer/GameOverOverlay/Center/Panel/VB/Buttons/PlayAgainButton") as Button
	leave_game_button = get_node_or_null("RoundDataContainer/GameOverOverlay/Center/Panel/VB/Buttons/LeaveGameButton") as Button

	hand_scroll = get_node_or_null("RoundDataContainer/HandScroll") as ScrollContainer
	hand_container = get_node_or_null("RoundDataContainer/HandScroll/HandContainer") as HBoxContainer

	# Backward-compatible fallback if a scene still uses direct HandContainer.
	if hand_container == null:
		hand_container = get_node_or_null("RoundDataContainer/HandContainer") as HBoxContainer

func _update_staged_put_down_ui() -> void:
	if staged_panel == null or staged_title_label == null or staged_container == null:
		return
	for child in staged_container.get_children():
		child.queue_free()
	var staged_cards_data: Array = GameManager.get_private_put_down_buffer()
	var staged_count: int = staged_cards_data.size()
	staged_title_label.text = "Staging Area (%d)" % staged_count
	if staged_count <= 0:
		staged_panel.visible = false
		return
	staged_panel.visible = true
	staged_container.add_theme_constant_override("separation", int(BASE_HAND_SPACING))
	for raw in staged_cards_data:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var card_dict: Dictionary = raw
		var card: Card = Card.from_dict(card_dict)
		if card == null:
			continue
		var card_view: CardView = CARD_VIEW_SCENE.instantiate() as CardView
		if card_view == null:
			continue
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_view.set_card(card)
		card_view.apply_scale_ratio(STAGED_CARD_SCALE)
		staged_container.add_child(card_view)
	if staged_scroll != null:
		staged_scroll.scroll_horizontal = 0

func _toggle_selected_card(card_view: CardView) -> void:
	if card_view == null:
		return
	if not _can_local_select_cards():
		return
	_prune_selected_cards()
	if card_view.is_selected():
		card_view.set_selected(false)
		_selected_cards.erase(card_view)
	else:
		card_view.set_selected(true)
		_selected_cards.append(card_view)
	_update_action_buttons_state()
	_update_claim_status_label()
	_refresh_meld_board_if_open()

func _prune_selected_cards() -> void:
	var next_selected: Array[CardView] = []
	for selected_card in _selected_cards:
		if not is_instance_valid(selected_card):
			continue
		if selected_card.get_parent() != hand_container:
			continue
		if not selected_card.is_selected():
			continue
		next_selected.append(selected_card)
	_selected_cards = next_selected

func _clear_selected_cards(update_ui: bool = true) -> void:
	for selected_card in _selected_cards:
		if is_instance_valid(selected_card):
			selected_card.set_selected(false)
	_selected_cards.clear()
	if update_ui:
		_update_action_buttons_state()
		_update_claim_status_label()
		_refresh_meld_board_if_open()

func _selected_cards_payload() -> Array:
	_prune_selected_cards()
	var payload: Array = []
	for selected_card in _selected_cards:
		if not is_instance_valid(selected_card):
			continue
		var card_data: Card = selected_card.get_card()
		if card_data == null:
			continue
		payload.append(card_data.to_dict())
	return payload

func _update_pile_view() -> void:
	if pile_title_label == null or pile_card_holder == null:
		return
	var top_card: Card = GameManager.get_discard_top_card()
	if top_card == null:
		pile_title_label.text = "Pile (empty)"
		if pile_card_view != null:
			pile_card_view.visible = false
		return
	pile_title_label.text = "Pile"
	var pile_view: CardView = _ensure_pile_card_view()
	if pile_view == null:
		return
	pile_view.visible = true
	pile_view.set_card(top_card)
	pile_view.apply_scale_ratio(PILE_CARD_SCALE)

func _ensure_pile_card_view() -> CardView:
	if pile_card_holder == null:
		return null
	if pile_card_view != null and is_instance_valid(pile_card_view):
		return pile_card_view
	var existing_node: Node = pile_card_holder.get_node_or_null("PileCardView")
	if existing_node is CardView:
		pile_card_view = existing_node as CardView
		return pile_card_view
	var new_pile_card_view: CardView = CARD_VIEW_SCENE.instantiate() as CardView
	if new_pile_card_view == null:
		return null
	new_pile_card_view.name = "PileCardView"
	new_pile_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile_card_holder.add_child(new_pile_card_view)
	pile_card_view = new_pile_card_view
	return pile_card_view

func _update_round_rules_ui() -> void:
	if round_rules_label == null:
		return
	var round_num: int = int(GameManager.round_number)
	var requirement: Dictionary = GameManager.get_current_round_requirement_dict()
	if GameManager.game_over:
		round_rules_label.text = "Game Over\nOpen Score Sheet for final standings."
		return
	if requirement.is_empty():
		round_rules_label.text = "Round %d Requirements\nWaiting for rules from server..." % round_num
		return

	var sets_required: int = int(requirement.get("sets_of_3", 0))
	var runs4_required: int = int(requirement.get("runs_of_4", 0))
	var runs7_required: int = int(requirement.get("runs_of_7", 0))
	var all_cards_required: bool = bool(requirement.get("all_cards", false))
	var local_peer_id: int = multiplayer.get_unique_id()
	var progress: Dictionary = GameManager.get_put_down_progress_for_peer(local_peer_id)
	var set_numbers: Array[int] = _variant_to_int_array(progress.get("set_numbers", []))
	var run4_suits: Array[int] = _variant_to_int_array(progress.get("run4_suits", []))
	var run7_suits: Array[int] = _variant_to_int_array(progress.get("run7_suits", []))

	var slot_lines: Array[String] = []
	for i in range(sets_required):
		var set_line: String = "[ ] Set of 3 #%d" % [i + 1]
		if i < set_numbers.size():
			set_line = "[x] Set of 3 #%d (%s)" % [i + 1, _rank_text(set_numbers[i])]
		slot_lines.append(set_line)
	for i in range(runs4_required):
		var run4_line: String = "[ ] Run of 4 #%d" % [i + 1]
		if i < run4_suits.size():
			run4_line = "[x] Run of 4 #%d (%s)" % [i + 1, _suit_text(run4_suits[i])]
		slot_lines.append(run4_line)
	for i in range(runs7_required):
		var run7_line: String = "[ ] Run of 7 #%d" % [i + 1]
		if i < run7_suits.size():
			run7_line = "[x] Run of 7 #%d (%s)" % [i + 1, _suit_text(run7_suits[i])]
		slot_lines.append(run7_line)
	if slot_lines.is_empty():
		slot_lines.append("No meld slots required")

	var slots_text: String = ""
	for i in range(slot_lines.size()):
		if i > 0:
			slots_text += "\n"
		slots_text += slot_lines[i]

	var all_cards_text: String = "No"
	if all_cards_required:
		all_cards_text = "Yes"
	var put_down_status_text: String = "Pending"
	if local_peer_id > 0 and GameManager.has_player_put_down(local_peer_id):
		put_down_status_text = "Complete"

	round_rules_label.text = "Round %d Put Down Slots\n%s\nGo down when all slots are filled in one turn.\nRules: no duplicate set rank, no duplicate run suit\nAll cards required: %s\nWild cards: 2s\nYour put down: %s" % [
		round_num,
		slots_text,
		all_cards_text,
		put_down_status_text
	]

func _variant_to_int_array(values: Variant) -> Array[int]:
	var result: Array[int] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	var raw_array: Array = values
	for raw in raw_array:
		result.append(int(raw))
	return result

func _build_score_sheet_text() -> String:
	var lines: Array[String] = ["Score Sheet (lowest total wins)"]
	var score_sheet: Array = GameManager.get_score_sheet_data()
	if score_sheet.is_empty():
		lines.append("No round scores yet.")
	else:
		lines.append("Rounds:")
		for raw_round in score_sheet:
			if typeof(raw_round) != TYPE_DICTIONARY:
				continue
			var round_entry: Dictionary = raw_round
			var round_num: int = int(round_entry.get("round", 0))
			var row_parts: Array[String] = []
			var rows_raw: Variant = round_entry.get("rows", [])
			if typeof(rows_raw) == TYPE_ARRAY:
				var rows: Array = rows_raw
				for raw_row in rows:
					if typeof(raw_row) != TYPE_DICTIONARY:
						continue
					var row: Dictionary = raw_row
					row_parts.append("%s +%d" % [
						str(row.get("name", "Unknown")),
						int(row.get("round_points", 0))
					])
			if row_parts.is_empty():
				continue
			lines.append("R%d: %s" % [round_num, ", ".join(row_parts)])
	var totals: Array = _sorted_score_totals()
	if not totals.is_empty():
		lines.append("Totals:")
		for raw_total in totals:
			if typeof(raw_total) != TYPE_DICTIONARY:
				continue
			var total_row: Dictionary = raw_total
			lines.append("%s: %d" % [
				str(total_row.get("name", "Unknown")),
				int(total_row.get("score", 0))
			])
	if GameManager.game_over:
		lines.append(_game_over_status_text())
	return "\n".join(lines)

func _sorted_score_totals() -> Array:
	var totals: Array = []
	var peer_ids: Array = GameManager.players.keys()
	peer_ids.sort()
	for raw_peer_id in peer_ids:
		var peer_id: int = int(raw_peer_id)
		totals.append({
			"peer_id": peer_id,
			"name": _player_name_from_peer_id(peer_id),
			"score": _player_score_from_peer_id(peer_id)
		})
	totals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: int = int(a.get("score", 0))
		var score_b: int = int(b.get("score", 0))
		if score_a == score_b:
			return str(a.get("name", "")) < str(b.get("name", ""))
		return score_a < score_b
	)
	return totals

func _game_over_status_text() -> String:
	var winner_ids: Array = GameManager.get_winning_peer_ids()
	if winner_ids.is_empty():
		return "Game Over"
	var winner_names: Array[String] = []
	for raw_winner_id in winner_ids:
		winner_names.append(_player_name_from_peer_id(int(raw_winner_id)))
	if winner_names.size() == 1:
		return "Winner: %s" % winner_names[0]
	return "Winners: %s" % ", ".join(winner_names)

func _update_play_again_votes_from_state(state: Dictionary) -> void:
	_play_again_vote_peer_ids.clear()
	var raw_votes: Variant = state.get("play_again_peer_ids", [])
	if typeof(raw_votes) != TYPE_ARRAY:
		return
	var raw_votes_array: Array = raw_votes
	for raw_peer_id in raw_votes_array:
		_play_again_vote_peer_ids.append(int(raw_peer_id))

func _local_has_play_again_vote() -> bool:
	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	return _play_again_vote_peer_ids.has(local_peer_id)

func _update_game_over_overlay() -> void:
	if game_over_overlay == null:
		return
	var is_game_over: bool = GameManager.game_over
	game_over_overlay.visible = is_game_over
	if not is_game_over:
		if play_again_game_button != null:
			play_again_game_button.disabled = false
		return

	if game_over_title_label != null:
		game_over_title_label.text = _game_over_status_text()
	if game_over_scores_text != null:
		game_over_scores_text.clear()
		game_over_scores_text.add_text(_build_score_sheet_text())
		game_over_scores_text.scroll_to_line(0)

	var total_players: int = int(GameManager.players.size())
	var vote_count: int = int(_play_again_vote_peer_ids.size())
	var local_voted: bool = _local_has_play_again_vote()
	if play_again_game_button != null:
		play_again_game_button.disabled = local_voted or total_players < 2
	if game_over_status_label != null:
		if total_players < 2:
			game_over_status_label.text = "Only one player connected. Returning to start screen..."
		elif vote_count >= total_players:
			game_over_status_label.text = "All players ready. Restarting game..."
		elif local_voted:
			game_over_status_label.text = "Waiting for other players... (%d/%d ready)" % [vote_count, total_players]
		else:
			game_over_status_label.text = "Press Play Again when you are ready. (%d/%d ready)" % [vote_count, total_players]

func _on_end_turn_pressed() -> void:
	_debug_turn_state("end_turn_pressed_before")
	if not _can_local_end_turn():
		_update_end_turn_button_state()
		_debug_turn_state("end_turn_pressed_blocked_invalid_state")
		return

	if end_turn_button != null:
		end_turn_button.disabled = true

	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_end_turn(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_end_turn")
	_debug_turn_state("end_turn_pressed_sent")

func _update_end_turn_button_state() -> void:
	if end_turn_button == null:
		return
	# TODO: Replace this simple gate with full turn validation for melds (sets/runs) and go-out checks.
	end_turn_button.disabled = not _can_local_end_turn()
	_debug_turn_state("update_end_turn_button_state")

func _update_action_buttons_state() -> void:
	_prune_selected_cards()
	var turn_discard_completed: bool = GameManager.turn_discard_completed
	var can_put_down: bool = _can_local_put_down()
	var selected_count: int = _selected_cards.size()

	if pass_pile_button != null:
		pass_pile_button.disabled = not _can_local_pass_claim_offer()
	if claim_pile_button != null:
		claim_pile_button.disabled = turn_discard_completed or not _can_local_claim_pile()
	if put_down_button != null:
		put_down_button.disabled = not (can_put_down and selected_count > 0)
	if discard_selected_button != null:
		discard_selected_button.disabled = not (_can_local_discard_card() and selected_count == 1)
	if clear_selection_button != null:
		clear_selection_button.disabled = selected_count <= 0
	if debug_end_game_button != null:
		debug_end_game_button.disabled = GameManager.game_over
	_update_turn_pickup_overlay()

func _can_local_end_turn() -> bool:
	if GameManager.game_over:
		return false
	if not _is_local_players_turn():
		return false
	return GameManager.turn_discard_completed

func _can_local_put_down() -> bool:
	if GameManager.game_over:
		return false
	if not _is_local_players_turn():
		return false
	if GameManager.claim_window_active:
		return false
	if not GameManager.turn_pickup_completed:
		return false
	if GameManager.turn_discard_completed:
		return false
	var local_peer_id: int = multiplayer.get_unique_id()
	return not GameManager.has_player_put_down(local_peer_id)

func _can_local_add_to_meld_state() -> bool:
	if GameManager.game_over:
		return false
	if not _is_local_players_turn():
		return false
	if GameManager.claim_window_active:
		return false
	if not GameManager.turn_pickup_completed:
		return false
	if GameManager.turn_discard_completed:
		return false
	var local_peer_id: int = multiplayer.get_unique_id()
	return GameManager.has_player_put_down(local_peer_id)

func _can_local_select_cards() -> bool:
	return _can_local_put_down() or _can_local_add_to_meld_state()

func _can_local_discard_card() -> bool:
	if GameManager.game_over:
		return false
	if not _is_local_players_turn():
		return false
	if GameManager.claim_window_active:
		return false
	if not GameManager.turn_pickup_completed:
		return false
	return not GameManager.turn_discard_completed

func _is_local_players_turn() -> bool:
	if GameManager.game_over:
		return false
	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	var current_turn_peer_id: int = GameManager.get_current_player_peer_id()
	return current_turn_peer_id != -1 and current_turn_peer_id == local_peer_id

func _can_local_claim_pile() -> bool:
	if GameManager.game_over:
		return false
	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	if _local_claim_offer_passed:
		return false
	if not GameManager.claim_window_active:
		return false
	if GameManager.claim_opened_by_peer_id == local_peer_id:
		return false
	return not _is_local_players_turn()

func _can_local_pass_claim_offer() -> bool:
	if GameManager.game_over:
		return false
	if _local_claim_offer_passed:
		return false
	if not GameManager.claim_window_active:
		return false
	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	if GameManager.claim_opened_by_peer_id == local_peer_id:
		return false
	return not _is_local_players_turn()

func _should_show_turn_pickup_overlay() -> bool:
	if GameManager.game_over:
		return false
	if GameManager.claim_window_active:
		return false
	if GameManager.turn_pickup_completed:
		return false
	return _is_local_players_turn()

func _update_turn_pickup_overlay() -> void:
	if turn_pickup_overlay == null:
		return
	var show_overlay: bool = _should_show_turn_pickup_overlay()
	turn_pickup_overlay.visible = show_overlay
	if not show_overlay:
		return
	if turn_pickup_title_label != null:
		turn_pickup_title_label.text = "Your Turn"
	var has_pile_card: bool = GameManager.get_discard_top_card() != null
	if turn_pickup_status_label != null:
		if has_pile_card:
			turn_pickup_status_label.text = "Pick up from deck or discard pile."
		else:
			turn_pickup_status_label.text = "Discard pile is empty. Pick up from deck."
	if turn_pickup_deck_button != null:
		turn_pickup_deck_button.disabled = false
	if turn_pickup_discard_button != null:
		turn_pickup_discard_button.disabled = not has_pile_card

func _on_turn_pickup_deck_pressed() -> void:
	if not _should_show_turn_pickup_overlay():
		_update_turn_pickup_overlay()
		return
	if turn_pickup_deck_button != null:
		turn_pickup_deck_button.disabled = true
	if turn_pickup_discard_button != null:
		turn_pickup_discard_button.disabled = true
	_on_draw_deck_pressed()
	call_deferred("_update_turn_pickup_overlay")

func _on_turn_pickup_discard_pressed() -> void:
	if not _should_show_turn_pickup_overlay():
		_update_turn_pickup_overlay()
		return
	if turn_pickup_deck_button != null:
		turn_pickup_deck_button.disabled = true
	if turn_pickup_discard_button != null:
		turn_pickup_discard_button.disabled = true
	_on_take_pile_pressed()
	call_deferred("_update_turn_pickup_overlay")

func _on_draw_deck_pressed() -> void:
	if not _should_show_turn_pickup_overlay():
		return
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_draw_from_deck(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_draw_from_deck")

func _on_take_pile_pressed() -> void:
	if not _should_show_turn_pickup_overlay():
		return
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_take_from_pile(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_take_from_pile")

func _on_pass_pile_pressed() -> void:
	if not _can_local_pass_claim_offer():
		_update_action_buttons_state()
		return
	_local_claim_offer_passed = true
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_pass_pile(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_pass_pile")
	_update_action_buttons_state()
	_update_claim_status_label()

func _request_discard_card(card_view: CardView) -> void:
	if card_view == null:
		return
	if not _can_local_discard_card():
		return
	var card_data: Card = card_view.get_card()
	if card_data == null:
		return
	var card_dict: Dictionary = card_data.to_dict()
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_discard_card(local_peer_id, card_dict)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_discard_card", card_dict)

func _on_discard_selected_pressed() -> void:
	if not _can_local_discard_card():
		_update_action_buttons_state()
		return
	var payload: Array = _selected_cards_payload()
	if payload.size() != 1:
		_update_action_buttons_state()
		return
	var card_variant: Variant = payload[0]
	if typeof(card_variant) != TYPE_DICTIONARY:
		_update_action_buttons_state()
		return
	var card_dict: Dictionary = card_variant
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_discard_card(local_peer_id, card_dict)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_discard_card", card_dict)
	_update_action_buttons_state()

func _on_put_down_pressed() -> void:
	_put_down_error_text = ""
	_put_down_error_until_msec = 0
	if not _can_local_put_down():
		_update_action_buttons_state()
		return
	var payload: Array = _selected_cards_payload()
	if payload.is_empty():
		_update_action_buttons_state()
		return
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_put_down(local_peer_id, payload)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_put_down", payload)
	_update_action_buttons_state()

func _on_clear_selection_pressed() -> void:
	_clear_selected_cards()

func _on_claim_pile_pressed() -> void:
	if claim_pile_button != null:
		claim_pile_button.disabled = true
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_claim_pile(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_claim_pile")

func _on_meld_board_pressed() -> void:
	_ensure_meld_board_popup()
	_refresh_meld_board()
	if _meld_board_popup != null:
		_meld_board_popup.popup_centered(Vector2i(760, 420))

func _on_score_sheet_pressed() -> void:
	_ensure_score_sheet_popup()
	_refresh_score_sheet_popup()
	if _score_sheet_popup != null:
		_score_sheet_popup.popup_centered(Vector2i(760, 460))

func _on_debug_end_game_pressed() -> void:
	if GameManager.game_over:
		return
	if debug_end_game_button != null:
		debug_end_game_button.disabled = true
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_debug_end_game(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_debug_end_game")
	_update_action_buttons_state()

func _on_play_again_game_pressed() -> void:
	if not GameManager.game_over:
		return
	if play_again_game_button != null:
		play_again_game_button.disabled = true
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_play_again_vote(local_peer_id, true)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_play_again", true)
	_update_game_over_overlay()

func _on_leave_game_pressed() -> void:
	_disconnect_and_return_to_menu()

func _refresh_meld_board_if_open() -> void:
	if _meld_board_popup == null:
		return
	if not _meld_board_popup.visible:
		return
	_refresh_meld_board()

func _refresh_score_sheet_if_open() -> void:
	if _score_sheet_popup == null:
		return
	if not _score_sheet_popup.visible:
		return
	_refresh_score_sheet_popup()

func _disconnect_and_return_to_menu() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if Network_Manager.handler != null:
		Network_Manager.handler.queue_free()
		Network_Manager.handler = null
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _update_debug_controls_visibility() -> void:
	if debug_end_game_button == null:
		return
	debug_end_game_button.visible = bool(ProjectSettings.get_setting(DEBUG_UI_SETTING_PATH, false))

func _ensure_meld_board_popup() -> void:
	if _meld_board_popup != null:
		return
	var popup: AcceptDialog = AcceptDialog.new()
	popup.title = "Meld Board"
	popup.exclusive = false
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 320)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	popup.add_child(scroll)
	add_child(popup)
	_meld_board_popup = popup
	_meld_board_scroll = scroll
	_meld_board_list = list

func _ensure_score_sheet_popup() -> void:
	if _score_sheet_popup != null:
		return
	var popup: AcceptDialog = AcceptDialog.new()
	popup.title = "Score Sheet"
	popup.exclusive = false
	var score_text: RichTextLabel = RichTextLabel.new()
	score_text.custom_minimum_size = Vector2(720, 360)
	score_text.scroll_active = true
	score_text.bbcode_enabled = false
	score_text.fit_content = false
	score_text.selection_enabled = true
	score_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup.add_child(score_text)
	add_child(popup)
	_score_sheet_popup = popup
	_score_sheet_text = score_text

func _refresh_score_sheet_popup() -> void:
	if _score_sheet_text == null:
		return
	_score_sheet_text.clear()
	_score_sheet_text.add_text(_build_score_sheet_text())
	_score_sheet_text.scroll_to_line(0)

func _refresh_meld_board() -> void:
	if _meld_board_list == null:
		return
	for child in _meld_board_list.get_children():
		child.queue_free()

	var melds: Array = GameManager.get_public_melds()
	if melds.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No melds are down yet."
		_meld_board_list.add_child(empty_label)
		return

	for raw_meld in melds:
		if typeof(raw_meld) != TYPE_DICTIONARY:
			continue
		var meld_data: Dictionary = raw_meld
		var meld_id: int = int(meld_data.get("meld_id", -1))
		if meld_id < 0:
			continue
		var owner_peer_id: int = int(meld_data.get("owner_peer_id", -1))
		var owner_name: String = _player_name_from_peer_id(owner_peer_id)
		var type_text: String = _meld_type_text(meld_data)
		var cards_text: String = _meld_cards_text(meld_data)

		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content: VBoxContainer = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(content)

		var header: Label = Label.new()
		header.text = "%s - %s (Meld #%d)" % [owner_name, type_text, meld_id]
		content.add_child(header)

		var cards_label: Label = Label.new()
		cards_label.text = "Cards: %s" % cards_text
		cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(cards_label)

		if _can_local_add_to_meld(meld_data):
			var add_button: Button = Button.new()
			add_button.text = "Add Selected"
			add_button.disabled = _selected_cards_payload().size() != 1
			add_button.pressed.connect(_on_add_selected_to_meld_pressed.bind(meld_id))
			content.add_child(add_button)

		_meld_board_list.add_child(panel)

func _meld_type_text(meld_data: Dictionary) -> String:
	var group_type: String = str(meld_data.get("group_type", ""))
	match group_type:
		PutDownValidator.GROUP_SET_3:
			return "Set"
		PutDownValidator.GROUP_RUN_4:
			return "Run (4+)"
		PutDownValidator.GROUP_RUN_7:
			return "Run (7+)"
		_:
			return "Meld"

func _meld_cards_text(meld_data: Dictionary) -> String:
	var cards_data_variant: Variant = meld_data.get("cards_data", [])
	if typeof(cards_data_variant) != TYPE_ARRAY:
		return "(invalid)"
	var cards_data: Array = cards_data_variant
	var parts: Array[String] = []
	for raw_card in cards_data:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card_dict: Dictionary = raw_card
		var card: Card = Card.from_dict(card_dict)
		parts.append(_card_to_short_text(card))
	if parts.is_empty():
		return "(none)"
	var out: String = ""
	for i in range(parts.size()):
		if i > 0:
			out += ", "
		out += parts[i]
	return out

func _can_local_add_to_meld(meld_data: Dictionary) -> bool:
	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	var meld_id: int = int(meld_data.get("meld_id", -1))
	if meld_id < 0:
		return false
	return _can_local_add_to_meld_state()

func _on_add_selected_to_meld_pressed(meld_id: int) -> void:
	var payload: Array = _selected_cards_payload()
	if payload.size() != 1:
		_on_put_down_error("Select exactly one card to add to a meld.")
		_refresh_meld_board_if_open()
		return
	var card_variant: Variant = payload[0]
	if typeof(card_variant) != TYPE_DICTIONARY:
		_on_put_down_error("Selected card payload is invalid.")
		_refresh_meld_board_if_open()
		return
	var card_dict: Dictionary = card_variant
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_add_to_meld(local_peer_id, meld_id, card_dict)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_add_to_meld", meld_id, card_dict)
	_refresh_meld_board_if_open()

func _process(_delta: float) -> void:
	_update_claim_status_label()

func _update_claim_status_label() -> void:
	if claim_status_label == null:
		return
	if GameManager.game_over:
		claim_status_label.text = _game_over_status_text()
		return
	if not GameManager.claim_window_active:
		var now_msec: int = int(Time.get_ticks_msec())
		if now_msec <= _put_down_error_until_msec and not _put_down_error_text.is_empty():
			claim_status_label.text = _put_down_error_text
			return
		if _can_local_put_down():
			var requirement: Dictionary = GameManager.get_current_round_requirement_dict()
			var progress: Dictionary = GameManager.get_put_down_progress_for_peer(multiplayer.get_unique_id())
			var required_slots: int = int(requirement.get("sets_of_3", 0)) + int(requirement.get("runs_of_4", 0)) + int(requirement.get("runs_of_7", 0))
			var filled_slots: int = int(progress.get("sets_done", 0)) + int(progress.get("runs4_done", 0)) + int(progress.get("runs7_done", 0))
			var selected_count: int = _selected_cards_payload().size()
			if selected_count > 0:
				claim_status_label.text = "Selected %d cards. Put down one set/run at a time." % selected_count
			else:
				claim_status_label.text = "Fill slots %d/%d. Shift+Left click one meld (set 3+, run 4+/7+), then press Put Down. (2s are wild)" % [
					filled_slots,
					required_slots
				]
		elif _can_local_discard_card():
			if GameManager.has_player_put_down(multiplayer.get_unique_id()):
				claim_status_label.text = "Select 1 card, then press Discard Sel. You can also add to melds."
			else:
				claim_status_label.text = "Select 1 card, then press Discard Sel."
		elif _is_local_players_turn() and not GameManager.turn_pickup_completed:
			claim_status_label.text = "Pick up a card to begin your turn."
		elif _can_local_end_turn():
			claim_status_label.text = "Discard complete. You can end your turn."
		else:
			claim_status_label.text = ""
		return
	if _local_claim_offer_passed:
		claim_status_label.text = "You passed on this pile offer."
		return
	var now_unix: int = int(Time.get_unix_time_from_system())
	var remaining: int = maxi(0, GameManager.claim_deadline_unix - now_unix)
	var card_text: String = _card_to_short_text(GameManager.get_discard_top_card())
	claim_status_label.text = "Claim window: %ds for %s" % [remaining, card_text]

func _on_pile_claimed_notification(claimant_peer_id: int, card_data: Dictionary, extra_card_drawn: bool) -> void:
	_ensure_claim_popup()
	if claim_popup == null:
		return
	var claimant_name: String = _player_name_from_peer_id(claimant_peer_id)
	var card_text: String = _card_dict_to_text(card_data)
	var extra_text: String = ""
	if extra_card_drawn:
		extra_text = " They also drew an extra card from the deck."
	claim_popup.dialog_text = "%s claimed %s from the pile.%s" % [claimant_name, card_text, extra_text]
	claim_popup.popup_centered(Vector2i(520, 180))

func _on_put_down_error(message: String) -> void:
	var clean_message: String = message.strip_edges()
	if clean_message.is_empty():
		return
	_put_down_error_text = clean_message
	_put_down_error_until_msec = int(Time.get_ticks_msec()) + PUT_DOWN_ERROR_DISPLAY_MS
	_ensure_put_down_error_popup()
	if put_down_error_popup != null:
		put_down_error_popup.dialog_text = clean_message
		put_down_error_popup.popup_centered(Vector2i(560, 180))
	_update_claim_status_label()

func _ensure_claim_popup() -> void:
	if claim_popup != null:
		return
	var popup: AcceptDialog = AcceptDialog.new()
	popup.title = "Pile Claimed"
	popup.exclusive = true
	add_child(popup)
	claim_popup = popup

func _ensure_put_down_error_popup() -> void:
	if put_down_error_popup != null:
		return
	var popup: AcceptDialog = AcceptDialog.new()
	popup.title = "Invalid Put Down"
	popup.exclusive = true
	add_child(popup)
	put_down_error_popup = popup

func _player_name_from_peer_id(peer_id: int) -> String:
	if GameManager.players.has(peer_id):
		var player_data: Variant = GameManager.players[peer_id]
		if player_data is Player:
			return (player_data as Player).name
		if typeof(player_data) == TYPE_DICTIONARY and player_data.has("name"):
			return str(player_data["name"])
	return "Player %s" % str(peer_id)

func _player_score_from_peer_id(peer_id: int) -> int:
	if not GameManager.players.has(peer_id):
		return 0
	var player_data: Variant = GameManager.players[peer_id]
	if player_data is Player:
		return int((player_data as Player).score)
	if typeof(player_data) == TYPE_DICTIONARY:
		var player_dict: Dictionary = player_data
		return int(player_dict.get("score", 0))
	return 0

func _card_dict_to_text(card_data: Dictionary) -> String:
	if card_data.is_empty():
		return "an unknown card"
	var card: Card = Card.from_dict(card_data)
	return _card_to_short_text(card)

func _card_to_short_text(card: Card) -> String:
	if card == null:
		return "unknown card"
	var rank: String = _rank_text(card.number)
	var suit: String = _suit_text(card.suit)
	return "%s%s" % [rank, suit]

func _rank_text(number: int) -> String:
	match number:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		_:
			return str(number)

func _suit_text(suit: int) -> String:
	match suit:
		Card.Suit.HEARTS:
			return "H"
		Card.Suit.DIAMONDS:
			return "D"
		Card.Suit.CLUBS:
			return "C"
		Card.Suit.SPADES:
			return "S"
		_:
			return "?"

func _debug_turn_state(context: String) -> void:
	if not TURN_DEBUG:
		return
	var local_peer_id: int = multiplayer.get_unique_id()
	var current_turn_peer_id: int = GameManager.get_current_player_peer_id()
	var current_idx: int = int(GameManager.current_player_index)
	var order_size: int = int(GameManager.player_order.size())
	var turn_pickup_completed: bool = GameManager.turn_pickup_completed
	var turn_discard_completed: bool = GameManager.turn_discard_completed
	var has_put_down: bool = GameManager.has_player_put_down(local_peer_id)
	var button_disabled_text: String = "n/a"
	if end_turn_button != null:
		button_disabled_text = str(end_turn_button.disabled)
	print("[TURN_DEBUG][UI][%s] local_peer=%s current_turn_peer=%s current_idx=%d order_size=%d pickup_done=%s discard_done=%s put_down=%s button_disabled=%s server=%s" % [
		context,
		str(local_peer_id),
		str(current_turn_peer_id),
		current_idx,
		order_size,
		str(turn_pickup_completed),
		str(turn_discard_completed),
		str(has_put_down),
		button_disabled_text,
		str(multiplayer.is_server() or OS.has_feature("server"))
	])
