extends Control

@onready var round_number_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/RoundNumberContainer/RoundNumber
@onready var current_player_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/CurrentPlayerContainer/CurrentPlayer

var hand_scroll: ScrollContainer = null
var hand_container: HBoxContainer = null
var hand_title: Label = null
var end_turn_button: Button = null
var draw_deck_button: Button = null
var take_pile_button: Button = null
var pass_pile_button: Button = null
var claim_pile_button: Button = null
var claim_status_label: Label = null
var claim_popup: AcceptDialog = null
var pile_title_label: Label = null
var pile_card_holder: CenterContainer = null
var pile_card_view: CardView = null

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/game/CardView.tscn")
const BASE_HAND_SPACING: float = 4.0
const PILE_CARD_SCALE: float = 1.0
const TURN_DEBUG: bool = true

var _dragging_card: CardView = null
var _drag_visual: CardView = null
var _drag_placeholder: PanelContainer = null
var _drag_mouse_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_resolve_hand_nodes()
	if end_turn_button != null:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if draw_deck_button != null:
		draw_deck_button.pressed.connect(_on_draw_deck_pressed)
	if take_pile_button != null:
		take_pile_button.pressed.connect(_on_take_pile_pressed)
	if pass_pile_button != null:
		pass_pile_button.pressed.connect(_on_pass_pile_pressed)
	if claim_pile_button != null:
		claim_pile_button.pressed.connect(_on_claim_pile_pressed)
	_update_end_turn_button_state()
	_update_action_buttons_state()
	_update_claim_status_label()
	_update_pile_view()
	_debug_turn_state("ready")
	SignalManager.round_updated.connect(update_round_ui)
	Game_State_Manager.game_state_updated.connect(_on_game_state_updated)
	Game_State_Manager.private_hand_updated.connect(_on_private_hand_updated)
	Game_State_Manager.pile_claimed_notification.connect(_on_pile_claimed_notification)
	set_process(true)
	if multiplayer.is_server() or OS.has_feature("server"):
		pull_round_ui()
	_render_local_hand()

func _on_game_state_updated(_state: Dictionary) -> void:
	_debug_turn_state("game_state_updated_pre")
	pull_round_ui()
	_update_action_buttons_state()
	_update_claim_status_label()
	_update_pile_view()
	_debug_turn_state("game_state_updated_post")

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
	_update_end_turn_button_state()
	_update_action_buttons_state()
	_update_claim_status_label()
	_update_pile_view()
	_debug_turn_state("update_round_ui")

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
	_update_end_turn_button_state()
	_update_action_buttons_state()
	_update_claim_status_label()
	_update_pile_view()

func _on_card_gui_input(event: InputEvent, card_view: CardView) -> void:
	if _dragging_card != null:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_request_discard_card(card_view)
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
	draw_deck_button = get_node_or_null("RoundDataContainer/ActionBar/DrawDeckButton") as Button
	take_pile_button = get_node_or_null("RoundDataContainer/ActionBar/TakePileButton") as Button
	pass_pile_button = get_node_or_null("RoundDataContainer/ActionBar/PassPileButton") as Button
	claim_pile_button = get_node_or_null("RoundDataContainer/ActionBar/ClaimPileButton") as Button
	claim_status_label = get_node_or_null("RoundDataContainer/ClaimStatusLabel") as Label
	pile_title_label = get_node_or_null("RoundDataContainer/PileContainer/PileTitle") as Label
	pile_card_holder = get_node_or_null("RoundDataContainer/PileContainer/PileCardHolder") as CenterContainer

	hand_scroll = get_node_or_null("RoundDataContainer/HandScroll") as ScrollContainer
	hand_container = get_node_or_null("RoundDataContainer/HandScroll/HandContainer") as HBoxContainer

	# Backward-compatible fallback if a scene still uses direct HandContainer.
	if hand_container == null:
		hand_container = get_node_or_null("RoundDataContainer/HandContainer") as HBoxContainer

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
	var is_turn: bool = _is_local_players_turn()
	var claim_active: bool = GameManager.claim_window_active
	var has_pile_card: bool = GameManager.get_discard_top_card() != null
	var turn_pickup_completed: bool = GameManager.turn_pickup_completed
	var turn_discard_completed: bool = GameManager.turn_discard_completed

	if draw_deck_button != null:
		draw_deck_button.disabled = not (is_turn and not claim_active and not turn_pickup_completed)
	if take_pile_button != null:
		take_pile_button.disabled = not (is_turn and not claim_active and has_pile_card and not turn_pickup_completed)
	if pass_pile_button != null:
		pass_pile_button.disabled = not (is_turn and not claim_active and has_pile_card and not turn_pickup_completed)
	if claim_pile_button != null:
		claim_pile_button.disabled = turn_discard_completed or not _can_local_claim_pile()

func _can_local_end_turn() -> bool:
	if not _is_local_players_turn():
		return false
	return GameManager.turn_discard_completed

func _can_local_discard_card() -> bool:
	if not _is_local_players_turn():
		return false
	if GameManager.claim_window_active:
		return false
	if not GameManager.turn_pickup_completed:
		return false
	return not GameManager.turn_discard_completed

func _is_local_players_turn() -> bool:
	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	var current_turn_peer_id: int = GameManager.get_current_player_peer_id()
	return current_turn_peer_id != -1 and current_turn_peer_id == local_peer_id

func _can_local_claim_pile() -> bool:
	var local_peer_id: int = multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return false
	if not GameManager.claim_window_active:
		return false
	if GameManager.claim_opened_by_peer_id == local_peer_id:
		return false
	return not _is_local_players_turn()

func _on_draw_deck_pressed() -> void:
	if draw_deck_button != null:
		draw_deck_button.disabled = true
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_draw_from_deck(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_draw_from_deck")

func _on_take_pile_pressed() -> void:
	if take_pile_button != null:
		take_pile_button.disabled = true
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_take_from_pile(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_take_from_pile")

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

func _on_pass_pile_pressed() -> void:
	if pass_pile_button != null:
		pass_pile_button.disabled = true
	if multiplayer.is_server() or OS.has_feature("server"):
		if Network_Manager.handler is ServerHandler:
			var local_peer_id: int = multiplayer.get_unique_id()
			(Network_Manager.handler as ServerHandler).register_pass_pile(local_peer_id)
	else:
		if multiplayer.multiplayer_peer != null:
			Network_Manager.rpc_id(1, "register_pass_pile")

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

func _process(_delta: float) -> void:
	_update_claim_status_label()

func _update_claim_status_label() -> void:
	if claim_status_label == null:
		return
	if not GameManager.claim_window_active:
		if _can_local_discard_card():
			claim_status_label.text = "Right-click a card to discard."
		elif _is_local_players_turn() and not GameManager.turn_pickup_completed:
			claim_status_label.text = "Pick up a card to begin your turn."
		elif _can_local_end_turn():
			claim_status_label.text = "Discard complete. You can end your turn."
		else:
			claim_status_label.text = ""
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

func _ensure_claim_popup() -> void:
	if claim_popup != null:
		return
	var popup: AcceptDialog = AcceptDialog.new()
	popup.title = "Pile Claimed"
	popup.exclusive = true
	add_child(popup)
	claim_popup = popup

func _player_name_from_peer_id(peer_id: int) -> String:
	if GameManager.players.has(peer_id):
		var player_data: Variant = GameManager.players[peer_id]
		if player_data is Player:
			return (player_data as Player).name
		if typeof(player_data) == TYPE_DICTIONARY and player_data.has("name"):
			return str(player_data["name"])
	return "Player %s" % str(peer_id)

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
	var button_disabled_text: String = "n/a"
	if end_turn_button != null:
		button_disabled_text = str(end_turn_button.disabled)
	print("[TURN_DEBUG][UI][%s] local_peer=%s current_turn_peer=%s current_idx=%d order_size=%d pickup_done=%s discard_done=%s button_disabled=%s server=%s" % [
		context,
		str(local_peer_id),
		str(current_turn_peer_id),
		current_idx,
		order_size,
		str(turn_pickup_completed),
		str(turn_discard_completed),
		button_disabled_text,
		str(multiplayer.is_server() or OS.has_feature("server"))
	])
