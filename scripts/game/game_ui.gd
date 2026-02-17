extends Control

@onready var round_number_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/RoundNumberContainer/RoundNumber
@onready var current_player_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/CurrentPlayerContainer/CurrentPlayer

var hand_scroll: ScrollContainer = null
var hand_container: HBoxContainer = null
var hand_title: Label = null

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/game/CardView.tscn")
const BASE_HAND_SPACING: float = 4.0

var _dragging_card: CardView = null
var _drag_visual: CardView = null
var _drag_placeholder: PanelContainer = null
var _drag_mouse_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_resolve_hand_nodes()
	SignalManager.round_updated.connect(update_round_ui)
	Game_State_Manager.game_state_updated.connect(_on_game_state_updated)
	Game_State_Manager.private_hand_updated.connect(_on_private_hand_updated)
	if multiplayer.is_server() or OS.has_feature("server"):
		pull_round_ui()
	_render_local_hand()

func _on_game_state_updated(_state: Dictionary) -> void:
	pull_round_ui()

func pull_round_ui() -> void:
	var round: int = GameManager.round_number
	var current_player_name: String = GameManager.get_player_name(GameManager.current_player_index)
	update_round_ui(round, current_player_name)


func update_round_ui(round: int, current_player_name: String) -> void:
	print("Updating round UI: Round %d, Current Player: %s" % [round, current_player_name])
	round_number_label.clear()
	round_number_label.parse_bbcode("[b]Round: [/b]%d" % round)
	
	current_player_label.clear()
	current_player_label.parse_bbcode("[b]Current Player: [/b]%s" % current_player_name)

func _on_private_hand_updated(_cards: Array) -> void:
	_render_local_hand()

func _render_local_hand() -> void:
	if not _ensure_hand_nodes():
		return
	_reset_drag_state()
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

func _on_card_gui_input(event: InputEvent, card_view: CardView) -> void:
	if _dragging_card != null:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
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

	hand_scroll = get_node_or_null("RoundDataContainer/HandScroll") as ScrollContainer
	hand_container = get_node_or_null("RoundDataContainer/HandScroll/HandContainer") as HBoxContainer

	# Backward-compatible fallback if a scene still uses direct HandContainer.
	if hand_container == null:
		hand_container = get_node_or_null("RoundDataContainer/HandContainer") as HBoxContainer
