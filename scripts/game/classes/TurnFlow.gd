extends RefCounted
class_name TurnFlow

const MOVE_DRAW_FROM_DECK: String = "draw_from_deck"
const MOVE_TAKE_FROM_PILE: String = "take_from_pile"
const MOVE_DISCARD_CARD: String = "discard_card"
const MOVE_END_TURN: String = "end_turn"
const MOVE_CLAIM_PILE: String = "claim_pile"
const MOVE_PASS_CLAIM: String = "pass_claim"
const MOVE_EXPIRE_CLAIM: String = "expire_claim"
const MOVE_PUT_DOWN_GATE: String = "put_down_gate"
const MOVE_ADD_TO_MELD_GATE: String = "add_to_meld_gate"

var game_manager: Node = null
var players: Dictionary = {}
var claim_passed_peer_ids: Dictionary = {}
var claim_pass_window_id: int = -1
var last_discard_peer_id: int = -1

func configure(game_manager_node: Node, players_registry: Dictionary) -> void:
	game_manager = game_manager_node
	players = players_registry

func apply_move(peer_id: int, move: Dictionary) -> Dictionary:
	var move_type: String = str(move.get("type", ""))
	match move_type:
		MOVE_DRAW_FROM_DECK:
			return _draw_from_deck(peer_id, move)
		MOVE_TAKE_FROM_PILE:
			return _take_from_pile(peer_id)
		MOVE_DISCARD_CARD:
			return _discard_card(peer_id, move)
		MOVE_END_TURN:
			return _end_turn(peer_id)
		MOVE_CLAIM_PILE:
			return _claim_pile(peer_id)
		MOVE_PASS_CLAIM:
			return _pass_claim(peer_id)
		MOVE_EXPIRE_CLAIM:
			return _expire_claim(int(move.get("claim_window_id", -1)))
		MOVE_PUT_DOWN_GATE:
			return _validate_turn_play_gate(peer_id, "put down")
		MOVE_ADD_TO_MELD_GATE:
			return _validate_turn_play_gate(peer_id, "add to meld")
		_:
			return _reject("Unknown turn flow move: %s" % move_type)

func reset_claim_tracking() -> void:
	_reset_claim_pass_tracking(-1)
	last_discard_peer_id = -1

func eligible_claim_peer_ids() -> Array:
	return _eligible_claim_peer_ids()

func passed_claim_peer_ids() -> Array:
	var eligible_peer_ids: Array = _eligible_claim_peer_ids()
	var passed: Array = []
	for raw_peer_id in claim_passed_peer_ids.keys():
		var peer_id: int = int(raw_peer_id)
		if eligible_peer_ids.has(peer_id):
			passed.append(peer_id)
	passed.sort()
	return passed

func _draw_from_deck(peer_id: int, move: Dictionary) -> Dictionary:
	var validation: Dictionary = _validate_current_turn_peer(peer_id)
	if not bool(validation.get("ok", false)):
		return validation
	if game_manager.turn_pickup_completed:
		return _reject("Ignoring draw request from %s: turn pickup already completed." % str(peer_id))
	if game_manager.claim_window_active:
		return _reject("Ignoring draw request from %s while claim window is active." % str(peer_id))
	var drawn_card: Card = game_manager.draw_card_from_deck_for_peer(peer_id)
	if drawn_card == null:
		return _reject("Draw from deck failed for peer %s (deck empty or unavailable)." % str(peer_id))
	game_manager.mark_turn_pickup_completed()
	var result: Dictionary = _accept()
	_add_private_hand_peer(result, peer_id)
	_add_private_put_down_peer(result, peer_id)
	var claim_started: bool = _start_claim_window(peer_id, int(move.get("claim_window_seconds", 30)), result)
	if claim_started:
		_add_log(result, "Peer %s drew from deck and auto-opened a %d second claim window." % [
			str(peer_id), int(move.get("claim_window_seconds", 30))
		])
	result["public_state_changed"] = true
	return result

func _take_from_pile(peer_id: int) -> Dictionary:
	var validation: Dictionary = _validate_current_turn_peer(peer_id)
	if not bool(validation.get("ok", false)):
		return validation
	if game_manager.turn_pickup_completed:
		return _reject("Ignoring take-pile request from %s: turn pickup already completed." % str(peer_id))
	if game_manager.claim_window_active:
		return _reject("Ignoring take-pile request from %s while claim window is active." % str(peer_id))
	var taken_card: Card = game_manager.take_discard_top_for_peer(peer_id)
	if taken_card == null:
		return _reject("Take from pile failed for peer %s (pile empty)." % str(peer_id))
	game_manager.mark_turn_pickup_completed()
	var result: Dictionary = _accept()
	_add_private_hand_peer(result, peer_id)
	_add_private_put_down_peer(result, peer_id)
	result["public_state_changed"] = true
	return result

func _discard_card(peer_id: int, move: Dictionary) -> Dictionary:
	var validation: Dictionary = _validate_current_turn_peer(peer_id)
	if not bool(validation.get("ok", false)):
		return validation
	if game_manager.claim_window_active:
		return _reject("Ignoring discard request from %s while claim window is active." % str(peer_id))
	if not game_manager.turn_pickup_completed:
		return _reject("Ignoring discard request from %s: player must pick up a card first." % str(peer_id))
	if game_manager.turn_discard_completed:
		return _reject("Ignoring discard request from %s: discard already completed this turn." % str(peer_id))
	var card_data: Dictionary = move.get("card_data", {})
	if card_data.is_empty():
		return _reject("Ignoring discard request from %s: invalid card payload." % str(peer_id))

	var requirement: RoundRequirement = game_manager.get_current_round_requirement()
	var all_cards_required: bool = requirement != null and bool(requirement.all_cards)
	var hand_size_before_discard: int = game_manager.get_hand_size_for_peer(peer_id)
	var is_final_card_discard: bool = hand_size_before_discard <= 1
	if all_cards_required and is_final_card_discard and not game_manager.has_player_put_down(peer_id):
		var all_cards_result: Dictionary = _reject("This round requires all cards. Go down with no cards left to win the round.")
		all_cards_result["put_down_error_peer_id"] = peer_id
		return all_cards_result

	var result: Dictionary = _accept()
	if not game_manager.has_player_put_down(peer_id):
		if game_manager.get_put_down_buffer_size_for_peer(peer_id) > 0:
			game_manager.reset_put_down_progress_for_peer(peer_id)
			_add_private_put_down_peer(result, peer_id)
			_add_log(result, "Peer %s discarded before going down. Cleared staged meld slots." % str(peer_id))

	var discarded_card: Card = game_manager.discard_card_from_peer(peer_id, card_data)
	if discarded_card == null:
		return _reject("Discard request from %s failed: card not found in hand." % str(peer_id))

	game_manager.mark_turn_discard_completed()
	last_discard_peer_id = peer_id
	_add_private_hand_peer(result, peer_id)
	_add_private_put_down_peer(result, peer_id)
	var remaining_cards: int = game_manager.get_hand_size_for_peer(peer_id)
	if remaining_cards <= 0:
		result["round_finished"] = {
			"peer_id": peer_id,
			"message": "Peer %s discarded their final card %s. Round is over." % [str(peer_id), str(discarded_card)]
		}
	else:
		result["public_state_changed"] = true
	return result

func _end_turn(peer_id: int) -> Dictionary:
	var validation: Dictionary = _validate_current_turn_peer(peer_id)
	if not bool(validation.get("ok", false)):
		return validation
	if not game_manager.turn_discard_completed:
		return _reject("Ignoring end turn from peer %s: they must discard before ending their turn." % str(peer_id))
	var result: Dictionary = _accept()
	if not game_manager.has_player_put_down(peer_id):
		if game_manager.get_put_down_buffer_size_for_peer(peer_id) > 0:
			game_manager.reset_put_down_progress_for_peer(peer_id)
			_add_private_put_down_peer(result, peer_id)
			_add_log(result, "Cleared incomplete put-down slots for peer %s at end turn." % str(peer_id))
	game_manager.advance_to_next_player()
	result["round_update"] = {
		"round": game_manager.round_number,
		"current_player_name": game_manager.get_player_name(game_manager.current_player_index)
	}
	_add_log(result, "Turn ended by peer %s. Next player is %s." % [
		str(peer_id), game_manager.get_player_name(game_manager.current_player_index)
	])
	result["public_state_changed"] = true
	return result

func _claim_pile(peer_id: int) -> Dictionary:
	if not players.has(peer_id):
		return _reject("Ignoring claim request from unknown peer %s." % str(peer_id))
	if not game_manager.claim_window_active:
		return _reject("Ignoring claim request from %s: no active claim window." % str(peer_id))
	if not _eligible_claim_peer_ids().has(peer_id):
		return _reject("Ignoring claim request from %s: peer is not eligible for this Claim Window." % str(peer_id))
	var now_unix: int = int(Time.get_unix_time_from_system())
	if game_manager.claim_deadline_unix > 0 and now_unix > game_manager.claim_deadline_unix:
		return _expire_claim(game_manager.claim_window_id)

	var claimed_card: Card = game_manager.take_discard_top_for_peer(peer_id)
	if claimed_card == null:
		var failed_claim: Dictionary = _expire_claim(game_manager.claim_window_id)
		_add_log(failed_claim, "Claim request from %s failed: discard pile empty." % str(peer_id))
		return failed_claim

	var extra_card: Card = game_manager.draw_card_from_deck_for_peer(peer_id)
	game_manager.clear_claim_window()
	_reset_claim_pass_tracking(-1)
	var result: Dictionary = _accept()
	_add_private_hand_peer(result, peer_id)
	_add_private_put_down_peer(result, peer_id)
	result["claim_notification"] = {
		"claimant_peer_id": peer_id,
		"card_data": claimed_card.to_dict(),
		"extra_card_drawn": extra_card != null
	}
	var extra_draw_text: String = "did not draw"
	if extra_card != null:
		extra_draw_text = "drew"
	_add_log(result, "Peer %s claimed pile card %s and %s an extra deck card." % [
		str(peer_id), str(claimed_card), extra_draw_text
	])
	result["public_state_changed"] = true
	return result

func _pass_claim(peer_id: int) -> Dictionary:
	if not players.has(peer_id):
		return _reject("Ignoring pass request from unknown peer %s." % str(peer_id))
	if not game_manager.claim_window_active:
		return _reject("Ignoring pass-pile request from %s: no active claim window." % str(peer_id))
	if not _eligible_claim_peer_ids().has(peer_id):
		return _reject("Ignoring pass-pile request from %s: peer is not eligible for this Claim Window." % str(peer_id))
	if claim_pass_window_id != game_manager.claim_window_id:
		_reset_claim_pass_tracking(game_manager.claim_window_id)
	if claim_passed_peer_ids.has(peer_id):
		return _reject("Ignoring pass-pile request from %s: already passed this Claim Window." % str(peer_id))
	claim_passed_peer_ids[peer_id] = true
	var result: Dictionary = _accept()
	_add_log(result, "Peer %s passed on the pile offer." % str(peer_id))
	if _all_eligible_claim_players_passed():
		_add_log(result, "All eligible players passed. Closing Claim Window early.")
		game_manager.clear_claim_window()
		_reset_claim_pass_tracking(-1)
	result["public_state_changed"] = true
	return result

func _expire_claim(expected_claim_id: int) -> Dictionary:
	if game_manager == null:
		return _reject("Cannot expire Claim Window: GameManager unavailable.")
	if not game_manager.claim_window_active:
		return _reject("Ignoring Claim Window expiry: no active Claim Window.")
	if game_manager.claim_window_id != expected_claim_id:
		return _reject("Ignoring stale Claim Window expiry for %s." % str(expected_claim_id))
	game_manager.clear_claim_window()
	_reset_claim_pass_tracking(-1)
	var result: Dictionary = _accept()
	_add_log(result, "Claim Window timed out with no winner.")
	result["public_state_changed"] = true
	return result

func _validate_turn_play_gate(peer_id: int, label: String) -> Dictionary:
	var validation: Dictionary = _validate_current_turn_peer(peer_id)
	if not bool(validation.get("ok", false)):
		return validation
	if game_manager.claim_window_active:
		return _reject("Cannot %s while Claim Window is active." % label)
	if not game_manager.turn_pickup_completed:
		return _reject("Pick up a card before attempting to %s." % label)
	if game_manager.turn_discard_completed:
		return _reject("Discard already completed. End your turn.")
	return _accept()

func _validate_current_turn_peer(peer_id: int) -> Dictionary:
	if game_manager == null:
		return _reject("Ignoring request from %s: GameManager unavailable." % str(peer_id))
	if not players.has(peer_id):
		return _reject("Ignoring request from unknown peer %s." % str(peer_id))
	if game_manager.game_over:
		return _reject("Ignoring request from %s: game is already over." % str(peer_id))
	var current_turn_peer_id: int = game_manager.get_current_player_peer_id()
	if current_turn_peer_id == -1:
		return _reject("Ignoring request from %s: no active current player." % str(peer_id))
	if current_turn_peer_id != peer_id:
		return _reject("Ignoring request from %s: current turn belongs to %s." % [
			str(peer_id), str(current_turn_peer_id)
		])
	return _accept()

func _start_claim_window(opened_by_peer_id: int, duration_seconds: int, result: Dictionary) -> bool:
	if game_manager == null:
		return false
	if game_manager.claim_window_active:
		return false
	if game_manager.get_discard_top_card() == null:
		return false
	var claim_id: int = game_manager.open_claim_window(opened_by_peer_id, duration_seconds)
	if claim_id == -1:
		return false
	_reset_claim_pass_tracking(claim_id)
	if last_discard_peer_id > 0:
		claim_passed_peer_ids[last_discard_peer_id] = true
		_add_log(result, "Peer %s is automatically passed for the Claim Window because they discarded the offered card." % str(last_discard_peer_id))
	if _all_eligible_claim_players_passed():
		game_manager.clear_claim_window()
		_reset_claim_pass_tracking(-1)
		return false
	result["claim_timer_claim_id"] = claim_id
	return true

func _eligible_claim_peer_ids() -> Array:
	var eligible: Array = []
	if game_manager == null:
		return eligible
	var opener_peer_id: int = int(game_manager.claim_opened_by_peer_id)
	var current_turn_peer_id: int = game_manager.get_current_player_peer_id()
	for raw_peer_id in players.keys():
		var peer_id: int = int(raw_peer_id)
		if peer_id == opener_peer_id:
			continue
		if peer_id == current_turn_peer_id:
			continue
		if peer_id == last_discard_peer_id:
			continue
		eligible.append(peer_id)
	eligible.sort()
	return eligible

func _all_eligible_claim_players_passed() -> bool:
	var eligible_peer_ids: Array = _eligible_claim_peer_ids()
	if eligible_peer_ids.is_empty():
		return true
	for raw_peer_id in eligible_peer_ids:
		var peer_id: int = int(raw_peer_id)
		if not claim_passed_peer_ids.has(peer_id):
			return false
	return true

func _reset_claim_pass_tracking(window_id: int) -> void:
	claim_pass_window_id = window_id
	claim_passed_peer_ids.clear()

func _accept() -> Dictionary:
	return {
		"ok": true,
		"reason": "",
		"log_messages": [],
		"public_state_changed": false,
		"private_hand_peer_ids": [],
		"private_put_down_peer_ids": [],
		"round_update": {},
		"claim_notification": {},
		"claim_timer_claim_id": -1,
		"round_finished": {},
		"put_down_error_peer_id": -1
	}

func _reject(reason: String) -> Dictionary:
	var result: Dictionary = _accept()
	result["ok"] = false
	result["reason"] = reason
	return result

func _add_log(result: Dictionary, message: String) -> void:
	if message.is_empty():
		return
	var messages: Array = result.get("log_messages", [])
	messages.append(message)
	result["log_messages"] = messages

func _add_private_hand_peer(result: Dictionary, peer_id: int) -> void:
	var peer_ids: Array = result.get("private_hand_peer_ids", [])
	if not peer_ids.has(peer_id):
		peer_ids.append(peer_id)
	result["private_hand_peer_ids"] = peer_ids

func _add_private_put_down_peer(result: Dictionary, peer_id: int) -> void:
	var peer_ids: Array = result.get("private_put_down_peer_ids", [])
	if not peer_ids.has(peer_id):
		peer_ids.append(peer_id)
	result["private_put_down_peer_ids"] = peer_ids
