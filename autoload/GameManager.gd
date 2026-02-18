extends Node

var host_flag : bool = false
var deck : Deck
var ruleset : Ruleset
# Player registries
var players: Dictionary = {} # key: peer_id, value: player_data
var player_order : Array = [] # ordered list of peer_ids for turn management
var player_hands : Dictionary = {} # key: peer_id, value: Array of Cards
var current_player_index : int = 0
var current_player_peer_id : int = -1
var starting_player_index : int = 0
var round_number : int = 1
var discard_pile: Array[Card] = []
var claim_window_active: bool = false
var claim_deadline_unix: int = 0
var claim_opened_by_peer_id: int = -1
var claim_window_id: int = 0
var turn_pickup_completed: bool = false
var turn_discard_completed: bool = false
var player_put_down_status: Dictionary = {} # key: peer_id, value: bool
var player_put_down_progress: Dictionary = {} # key: peer_id, value: put-down progress dict
var player_put_down_buffer: Dictionary = {} # key: peer_id, value: Array[Dictionary] (staged meld cards this turn)
var player_put_down_group_buffer: Dictionary = {} # key: peer_id, value: Array[Dictionary] (staged meld groups)
var player_committed_melds: Dictionary = {} # key: peer_id, value: Array[Dictionary] (melds visible to all)
var next_meld_id: int = 1
var public_melds_data: Array = [] # client-side snapshot cache
var current_round_requirement_data: Dictionary = {}
var private_put_down_buffer_data: Array = [] # client-only staged put-down cards for local player

const GAME_LOG_SETTING_PATH: String = "debug/game_logs"
const SNAPSHOT_LOG_SETTING_PATH: String = "debug/snapshot_logs"
const TURN_DEBUG: bool = true
const CLIENT_STATE_BIND_MAX_ATTEMPTS: int = 120

var _client_state_bind_attempts: int = 0

func _log_game(msg: String) -> void:
	if not ProjectSettings.get_setting(GAME_LOG_SETTING_PATH, true):
		return
	print(msg)

func _is_server_authority() -> bool:
	return multiplayer.is_server() or OS.has_feature("server")

func _ready() -> void:
	# Always try to bind snapshot updates; apply_game_state itself enforces authority checks.
	call_deferred("_ensure_client_state_binding")

# Load ruleset from file
func start_game(ruleset_path : String = "res://data/rulesets/default_ruleset.json") -> void:
	if not _is_server_authority():
		return
	var ruleset_loader: RulesetLoader = RulesetLoader.new()
	var loaded_ruleset: Ruleset = ruleset_loader.load_ruleset(ruleset_path)
	if loaded_ruleset != null:
		ruleset = loaded_ruleset
		_apply_debug_start_round()
		create_deck(players.size())
		deal_hand(round_number)
		initialize_discard_pile()
		reset_round_put_down_status()
		current_round_requirement_data = serialize_current_round_requirement()
		SignalManager.round_updated.emit(round_number, get_player_name(starting_player_index))
	else:
		printerr("Error loading ruleset: %s" % ruleset_loader.last_error)

# Create deck for the players based on player count
func create_deck(players: int) -> void:
	if not _is_server_authority():
		return
	deck = Deck.new(players)
	_log_game("Deck created for %d players." % players)

# Create hand for each player based on the hand count for that round
func deal_hand(round: int) -> void:
	if not _is_server_authority():
		return
	if deck == null:
		return
	player_hands.clear()
	var deal_count: int = _deal_count_for_round(round)
	if deal_count <= 0:
		deal_count = 7
	for pid in players.keys():
		player_hands[pid] = deck.deal_hand(deal_count)
		_log_game("Dealt hand to peer %s with %d cards." % [str(pid), player_hands[pid].size()])
	_log_game("Dealt %d cards to %d players." % [deal_count, players.size()])

func reset_hands() -> void:
	if not _is_server_authority():
		return
	player_hands.clear()

func initialize_discard_pile() -> void:
	if not _is_server_authority():
		return
	discard_pile.clear()
	clear_claim_window()
	if deck == null:
		return
	var top_card: Card = deck.draw_card()
	if top_card != null:
		discard_pile.append(top_card)

func get_discard_top_card() -> Card:
	if discard_pile.is_empty():
		return null
	return discard_pile[discard_pile.size() - 1]

func draw_card_from_deck_for_peer(peer_id: int) -> Card:
	if not _is_server_authority():
		return null
	if deck == null:
		return null
	var drawn_card: Card = deck.draw_card()
	if drawn_card == null:
		return null
	if not player_hands.has(peer_id):
		player_hands[peer_id] = []
	var hand_cards: Array = player_hands[peer_id]
	hand_cards.append(drawn_card)
	player_hands[peer_id] = hand_cards
	return drawn_card

func take_discard_top_for_peer(peer_id: int) -> Card:
	if not _is_server_authority():
		return null
	if discard_pile.is_empty():
		return null
	var taken_card: Card = discard_pile.pop_back()
	if not player_hands.has(peer_id):
		player_hands[peer_id] = []
	var hand_cards: Array = player_hands[peer_id]
	hand_cards.append(taken_card)
	player_hands[peer_id] = hand_cards
	return taken_card

func discard_card_from_peer(peer_id: int, card_data: Dictionary) -> Card:
	if not _is_server_authority():
		return null
	if card_data.is_empty():
		return null
	var hand_key: Variant = _resolve_hand_key_for_peer(peer_id)
	if hand_key == null:
		return null
	if not player_hands.has(hand_key):
		return null
	var hand_cards: Array = player_hands[hand_key]
	var target_signature: String = _card_signature_from_dict(card_data)
	if target_signature.is_empty():
		return null
	for i in range(hand_cards.size()):
		var hand_entry: Variant = hand_cards[i]
		if not (hand_entry is Card):
			continue
		var hand_card: Card = hand_entry as Card
		if _card_signature_for_card(hand_card) != target_signature:
			continue
		hand_cards.remove_at(i)
		player_hands[hand_key] = hand_cards
		discard_pile.append(hand_card)
		return hand_card
	return null

func remove_cards_from_peer_hand(peer_id: int, cards_data: Array) -> Array[Card]:
	if not _is_server_authority():
		return []
	if cards_data.is_empty():
		return []
	var hand_key: Variant = _resolve_hand_key_for_peer(peer_id)
	if hand_key == null:
		return []
	if not player_hands.has(hand_key):
		return []
	var source_hand: Array = player_hands[hand_key]
	var working_hand: Array = source_hand.duplicate()
	var removed_cards: Array[Card] = []
	for raw in cards_data:
		if typeof(raw) != TYPE_DICTIONARY:
			return []
		var card_dict: Dictionary = raw
		var target_signature: String = _card_signature_from_dict(card_dict)
		if target_signature.is_empty():
			return []
		var removed_index: int = -1
		for i in range(working_hand.size()):
			var hand_entry: Variant = working_hand[i]
			if not (hand_entry is Card):
				continue
			var hand_card: Card = hand_entry as Card
			if _card_signature_for_card(hand_card) != target_signature:
				continue
			removed_cards.append(hand_card)
			removed_index = i
			break
		if removed_index == -1:
			return []
		working_hand.remove_at(removed_index)
	player_hands[hand_key] = working_hand
	return removed_cards

func get_hand_size_for_peer(peer_id: int) -> int:
	var hand_key: Variant = _resolve_hand_key_for_peer(peer_id)
	if hand_key == null:
		return 0
	if not player_hands.has(hand_key):
		return 0
	var hand_cards: Array = player_hands[hand_key]
	return hand_cards.size()

func get_hand_cards_for_peer(peer_id: int) -> Array[Card]:
	var result: Array[Card] = []
	var hand_key: Variant = _resolve_hand_key_for_peer(peer_id)
	if hand_key == null:
		return result
	if not player_hands.has(hand_key):
		return result
	var hand_cards: Array = player_hands[hand_key]
	for entry in hand_cards:
		if entry is Card:
			result.append(entry as Card)
	return result

func get_current_round_requirement() -> RoundRequirement:
	if ruleset == null:
		return null
	var round_req: Variant = ruleset.get_round(round_number)
	if round_req is RoundRequirement:
		return round_req as RoundRequirement
	return null

func serialize_current_round_requirement() -> Dictionary:
	var requirement: RoundRequirement = get_current_round_requirement()
	if requirement == null:
		return {}
	return {
		"round": int(requirement.game_round),
		"sets_of_3": int(requirement.sets_of_3),
		"runs_of_4": int(requirement.runs_of_4),
		"runs_of_7": int(requirement.runs_of_7),
		"all_cards": bool(requirement.all_cards)
	}

func get_current_round_requirement_dict() -> Dictionary:
	if not current_round_requirement_data.is_empty():
		return current_round_requirement_data
	return serialize_current_round_requirement()

func open_claim_window(opened_by_peer_id: int, duration_seconds: int) -> int:
	if not _is_server_authority():
		return -1
	var top_card: Card = get_discard_top_card()
	if top_card == null:
		return -1
	claim_window_id += 1
	claim_window_active = true
	claim_opened_by_peer_id = opened_by_peer_id
	claim_deadline_unix = int(Time.get_unix_time_from_system()) + maxi(1, duration_seconds)
	return claim_window_id

func clear_claim_window() -> void:
	claim_window_active = false
	claim_deadline_unix = 0
	claim_opened_by_peer_id = -1

func mark_turn_pickup_completed() -> void:
	if not _is_server_authority():
		return
	turn_pickup_completed = true
	turn_discard_completed = false

func mark_turn_discard_completed() -> void:
	if not _is_server_authority():
		return
	turn_discard_completed = true

func reset_turn_pickup_completed() -> void:
	turn_pickup_completed = false
	turn_discard_completed = false

func reset_round_put_down_status() -> void:
	player_put_down_status.clear()
	player_put_down_progress.clear()
	player_put_down_buffer.clear()
	player_put_down_group_buffer.clear()
	player_committed_melds.clear()
	public_melds_data.clear()
	next_meld_id = 1
	for pid in players.keys():
		player_put_down_status[pid] = false
		player_put_down_progress[pid] = _build_default_put_down_progress()
		player_put_down_buffer[pid] = []
		player_put_down_group_buffer[pid] = []
		player_committed_melds[pid] = []

func has_player_put_down(peer_id: int) -> bool:
	if player_put_down_status.has(peer_id):
		return bool(player_put_down_status[peer_id])
	for key in player_put_down_status.keys():
		if int(key) == int(peer_id):
			return bool(player_put_down_status[key])
	return false

func set_player_put_down(peer_id: int, did_put_down: bool) -> void:
	if not _is_server_authority():
		return
	player_put_down_status[peer_id] = did_put_down

func get_put_down_player_ids() -> Array:
	var result: Array = []
	for key in player_put_down_status.keys():
		if bool(player_put_down_status[key]):
			result.append(int(key))
	result.sort()
	return result

func get_put_down_progress_for_peer(peer_id: int) -> Dictionary:
	if player_put_down_progress.has(peer_id):
		return _normalize_put_down_progress(player_put_down_progress[peer_id])
	for key in player_put_down_progress.keys():
		if int(key) == int(peer_id):
			return _normalize_put_down_progress(player_put_down_progress[key])
	return _build_default_put_down_progress()

func get_put_down_progress_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for key in player_put_down_progress.keys():
		var peer_id: int = int(key)
		snapshot[str(peer_id)] = _normalize_put_down_progress(player_put_down_progress[key])
	return snapshot

func get_put_down_buffer_for_peer(peer_id: int) -> Array:
	if player_put_down_buffer.has(peer_id):
		var staged_cards: Variant = player_put_down_buffer[peer_id]
		if typeof(staged_cards) == TYPE_ARRAY:
			return (staged_cards as Array).duplicate(true)
	for key in player_put_down_buffer.keys():
		if int(key) == int(peer_id):
			var staged_cards: Variant = player_put_down_buffer[key]
			if typeof(staged_cards) == TYPE_ARRAY:
				return (staged_cards as Array).duplicate(true)
	return []

func get_put_down_buffer_size_for_peer(peer_id: int) -> int:
	return get_put_down_buffer_for_peer(peer_id).size()

func append_put_down_buffer_for_peer(peer_id: int, cards_data: Array) -> void:
	if not _is_server_authority():
		return
	var staged_cards: Array = get_put_down_buffer_for_peer(peer_id)
	for card_data in cards_data:
		if typeof(card_data) != TYPE_DICTIONARY:
			continue
		staged_cards.append((card_data as Dictionary).duplicate(true))
	player_put_down_buffer[peer_id] = staged_cards

func get_put_down_group_buffer_for_peer(peer_id: int) -> Array:
	if player_put_down_group_buffer.has(peer_id):
		var staged_groups: Variant = player_put_down_group_buffer[peer_id]
		if typeof(staged_groups) == TYPE_ARRAY:
			return (staged_groups as Array).duplicate(true)
	for key in player_put_down_group_buffer.keys():
		if int(key) == int(peer_id):
			var staged_groups: Variant = player_put_down_group_buffer[key]
			if typeof(staged_groups) == TYPE_ARRAY:
				return (staged_groups as Array).duplicate(true)
	return []

func append_put_down_group_buffer_for_peer(peer_id: int, group_type: String, set_number: int, run_suit: int, cards_data: Array) -> void:
	if not _is_server_authority():
		return
	var staged_groups: Array = get_put_down_group_buffer_for_peer(peer_id)
	var cards_copy: Array = []
	for raw in cards_data:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		cards_copy.append((raw as Dictionary).duplicate(true))
	var group_data: Dictionary = {
		"group_type": group_type,
		"set_number": set_number,
		"run_suit": run_suit,
		"cards_data": cards_copy
	}
	staged_groups.append(group_data)
	player_put_down_group_buffer[peer_id] = staged_groups

func clear_put_down_group_buffer_for_peer(peer_id: int) -> void:
	if not _is_server_authority():
		return
	player_put_down_group_buffer[peer_id] = []

func clear_put_down_buffer_for_peer(peer_id: int) -> void:
	if not _is_server_authority():
		return
	player_put_down_buffer[peer_id] = []

func reset_put_down_progress_for_peer(peer_id: int) -> void:
	if not _is_server_authority():
		return
	player_put_down_status[peer_id] = false
	player_put_down_progress[peer_id] = _build_default_put_down_progress()
	player_put_down_buffer[peer_id] = []
	player_put_down_group_buffer[peer_id] = []

func commit_staged_put_down_groups_for_peer(peer_id: int) -> int:
	if not _is_server_authority():
		return 0
	var staged_groups: Array = get_put_down_group_buffer_for_peer(peer_id)
	if staged_groups.is_empty():
		return 0
	var owner_melds: Array = []
	if player_committed_melds.has(peer_id):
		var existing_melds: Variant = player_committed_melds[peer_id]
		if typeof(existing_melds) == TYPE_ARRAY:
			owner_melds = (existing_melds as Array).duplicate(true)
	var committed_count: int = 0
	for raw_group in staged_groups:
		if typeof(raw_group) != TYPE_DICTIONARY:
			continue
		var staged_group: Dictionary = raw_group
		var cards_data_variant: Variant = staged_group.get("cards_data", [])
		if typeof(cards_data_variant) != TYPE_ARRAY:
			continue
		var cards_data: Array = cards_data_variant
		if cards_data.is_empty():
			continue
		var meld_data: Dictionary = staged_group.duplicate(true)
		meld_data["meld_id"] = next_meld_id
		meld_data["owner_peer_id"] = peer_id
		next_meld_id += 1
		owner_melds.append(meld_data)
		committed_count += 1
	player_committed_melds[peer_id] = owner_melds
	clear_put_down_group_buffer_for_peer(peer_id)
	return committed_count

func get_committed_meld_by_id(meld_id: int) -> Dictionary:
	for owner_key in player_committed_melds.keys():
		var melds_variant: Variant = player_committed_melds[owner_key]
		if typeof(melds_variant) != TYPE_ARRAY:
			continue
		var melds: Array = melds_variant
		for raw_meld in melds:
			if typeof(raw_meld) != TYPE_DICTIONARY:
				continue
			var meld_data: Dictionary = raw_meld
			if int(meld_data.get("meld_id", -1)) != meld_id:
				continue
			var copy: Dictionary = meld_data.duplicate(true)
			copy["owner_peer_id"] = int(copy.get("owner_peer_id", int(owner_key)))
			return copy
	return {}

func add_card_to_committed_meld(meld_id: int, card_data: Dictionary) -> bool:
	if not _is_server_authority():
		return false
	if card_data.is_empty():
		return false
	for owner_key in player_committed_melds.keys():
		var melds_variant: Variant = player_committed_melds[owner_key]
		if typeof(melds_variant) != TYPE_ARRAY:
			continue
		var melds: Array = melds_variant
		for i in range(melds.size()):
			var raw_meld: Variant = melds[i]
			if typeof(raw_meld) != TYPE_DICTIONARY:
				continue
			var meld_data: Dictionary = raw_meld
			if int(meld_data.get("meld_id", -1)) != meld_id:
				continue
			var cards_data_variant: Variant = meld_data.get("cards_data", [])
			if typeof(cards_data_variant) != TYPE_ARRAY:
				return false
			var cards_data: Array = cards_data_variant
			cards_data.append(card_data.duplicate(true))
			meld_data["cards_data"] = cards_data
			melds[i] = meld_data
			player_committed_melds[owner_key] = melds
			return true
	return false

func serialize_public_melds() -> Array:
	var result: Array = []
	for owner_key in player_committed_melds.keys():
		var melds_variant: Variant = player_committed_melds[owner_key]
		if typeof(melds_variant) != TYPE_ARRAY:
			continue
		var melds: Array = melds_variant
		for raw_meld in melds:
			if typeof(raw_meld) != TYPE_DICTIONARY:
				continue
			var meld_data: Dictionary = (raw_meld as Dictionary).duplicate(true)
			meld_data["owner_peer_id"] = int(meld_data.get("owner_peer_id", int(owner_key)))
			result.append(meld_data)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("meld_id", 0)) < int(b.get("meld_id", 0))
	)
	return result

func get_public_melds() -> Array:
	if _is_server_authority():
		return serialize_public_melds()
	return public_melds_data.duplicate(true)

func record_put_down_group(peer_id: int, group_type: String, set_number: int = -1, run_suit: int = -1) -> Dictionary:
	if not _is_server_authority():
		return {}
	var progress: Dictionary = get_put_down_progress_for_peer(peer_id)
	match group_type:
		PutDownValidator.GROUP_SET_3:
			progress["sets_done"] = int(progress.get("sets_done", 0)) + 1
			var set_numbers: Array[int] = _to_int_array(progress.get("set_numbers", []))
			if set_number >= 0 and not set_numbers.has(set_number):
				set_numbers.append(set_number)
			progress["set_numbers"] = set_numbers
		PutDownValidator.GROUP_RUN_4:
			progress["runs4_done"] = int(progress.get("runs4_done", 0)) + 1
			var run_suits4: Array[int] = _to_int_array(progress.get("run_suits", []))
			if run_suit >= 0 and not run_suits4.has(run_suit):
				run_suits4.append(run_suit)
			progress["run_suits"] = run_suits4
			var run4_suits: Array[int] = _to_int_array(progress.get("run4_suits", []))
			if run_suit >= 0 and not run4_suits.has(run_suit):
				run4_suits.append(run_suit)
			progress["run4_suits"] = run4_suits
		PutDownValidator.GROUP_RUN_7:
			progress["runs7_done"] = int(progress.get("runs7_done", 0)) + 1
			var run_suits7: Array[int] = _to_int_array(progress.get("run_suits", []))
			if run_suit >= 0 and not run_suits7.has(run_suit):
				run_suits7.append(run_suit)
			progress["run_suits"] = run_suits7
			var run7_suits: Array[int] = _to_int_array(progress.get("run7_suits", []))
			if run_suit >= 0 and not run7_suits.has(run_suit):
				run7_suits.append(run_suit)
			progress["run7_suits"] = run7_suits
		_:
			return _normalize_put_down_progress(progress)
	player_put_down_progress[peer_id] = _normalize_put_down_progress(progress)
	return player_put_down_progress[peer_id]

func evaluate_player_put_down_complete(peer_id: int) -> bool:
	var requirement: RoundRequirement = get_current_round_requirement()
	if requirement == null:
		return false
	var progress: Dictionary = get_put_down_progress_for_peer(peer_id)
	var sets_done: int = int(progress.get("sets_done", 0))
	var runs4_done: int = int(progress.get("runs4_done", 0))
	var runs7_done: int = int(progress.get("runs7_done", 0))
	if sets_done < int(requirement.sets_of_3):
		return false
	if runs4_done < int(requirement.runs_of_4):
		return false
	if runs7_done < int(requirement.runs_of_7):
		return false
	if bool(requirement.all_cards):
		if get_put_down_buffer_size_for_peer(peer_id) != get_hand_size_for_peer(peer_id):
			return false
	return true

func staged_put_down_is_complete_for_peer(peer_id: int) -> bool:
	if not evaluate_player_put_down_complete(peer_id):
		return false
	return true

func serialize_discard_top() -> Dictionary:
	var top_card: Card = get_discard_top_card()
	if top_card == null:
		return {}
	return top_card.to_dict()

func serialize_claim_card() -> Dictionary:
	var top_card: Card = get_discard_top_card()
	if top_card == null:
		return {}
	return top_card.to_dict()

func get_player_name(index: int) -> String:
	if player_order.is_empty():
		return "unknown"

	var safe_index: int = clampi(index, 0, player_order.size() - 1)
	var player_entry: Variant = player_order[safe_index]
	var peer_id: int = _extract_peer_id_from_player_entry(player_entry)
	if peer_id == -1:
		return "unknown"

	if players.has(peer_id):
		var player_data: Variant = players[peer_id]
		if player_data is Player:
			return (player_data as Player).name
		if typeof(player_data) == TYPE_DICTIONARY and player_data.has("name"):
			return str(player_data["name"])
	return "unknown"

func get_current_player_peer_id() -> int:
	if current_player_peer_id != -1:
		return current_player_peer_id
	if player_order.is_empty():
		return -1
	var safe_index: int = clampi(current_player_index, 0, player_order.size() - 1)
	var player_entry: Variant = player_order[safe_index]
	current_player_peer_id = _extract_peer_id_from_player_entry(player_entry)
	return current_player_peer_id

func load_players(player_data: Dictionary) -> void:
	if not _is_server_authority():
		return
	players = player_data
	_rebuild_player_order()
	_sync_put_down_status_for_players()
	for x in players.keys():
		_log_game("GameManager loaded player: %s" % players[x].name)

func _rebuild_player_order() -> void:
	player_order = []
	var ids: Array = players.keys()
	ids.sort()
	for pid in ids:
		player_order.append(players[pid])
	_refresh_current_player_peer_id()

func _deal_count_for_round(round: int) -> int:
	if ruleset == null:
		return 7
	var req: Variant = ruleset.get_round(round)
	if req == null:
		return 7
	var count: int = int(req.deal_count)
	if count <= 0:
		return 7
	return count

func _apply_debug_start_round() -> void:
	var configured_round: int = int(ProjectSettings.get_setting("debug/start_round", 1))
	var max_rounds: int = 1
	if ruleset != null:
		max_rounds = int(ruleset.max_rounds)
	if max_rounds <= 0:
		max_rounds = 1
	round_number = clamp(configured_round, 1, max_rounds)
	current_player_index = 0
	starting_player_index = 0
	reset_turn_pickup_completed()
	_refresh_current_player_peer_id()
	_log_game("Starting game at round %d (debug/start_round=%d)." % [round_number, configured_round])

func increment_starting_player() -> void:
	if not _is_server_authority():
		return
	if player_order.is_empty():
		return
	starting_player_index = (starting_player_index + 1) % player_order.size()
	current_player_index = starting_player_index
	reset_turn_pickup_completed()
	_refresh_current_player_peer_id()
	_log_game("Starting player changed to index %d (%s)" % [starting_player_index, get_player_name(starting_player_index)])

func advance_to_next_player() -> void:
	if not _is_server_authority():
		return
	if player_order.is_empty():
		return
	current_player_index = (current_player_index + 1) % player_order.size()
	reset_turn_pickup_completed()
	_refresh_current_player_peer_id()
	_log_game("Current player advanced to index %d (%s)" % [current_player_index, get_player_name(current_player_index)])

func advance_to_next_round() -> void:
	if not _is_server_authority():
		return
	if player_order.is_empty():
		return
	round_number += 1
	increment_starting_player()
	current_player_index = starting_player_index
	_refresh_current_player_peer_id()
	_log_game("Advancing to round %d" % round_number)
	SignalManager.round_updated.emit(round_number, get_player_name(current_player_index))
	reset_hands()
	deal_hand(round_number)
	initialize_discard_pile()
	reset_round_put_down_status()
	current_round_requirement_data = serialize_current_round_requirement()

# Client-only: apply authoritative snapshot from server.
func apply_game_state(state: Dictionary) -> void:
	if _is_server_authority():
		return
	if not state.has("players"):
		return
	var players_array: Array = state.get("players", [])
	var order_ids: Array = state.get("player_order_ids", [])
	var new_players: Dictionary = {}
	for p in players_array:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var player: Player = Player.new()
		player.peer_id = int(p.get("peer_id", -1))
		player.name = p.get("name", "")
		player.ready = p.get("ready", false)
		player.current_phase = p.get("current_phase", 1)
		player.score = p.get("score", 0)
		if player.peer_id < 0:
			continue
		new_players[player.peer_id] = player
	players = new_players
	player_order = []
	if order_ids.size() > 0:
		for pid_raw in order_ids:
			var pid: int = int(pid_raw)
			if players.has(pid):
				player_order.append(players[pid])
	# Fallback if order list was missing or had type mismatches.
	if player_order.is_empty():
		for p in players.values():
			player_order.append(p)
		player_order.sort_custom(func(a: Player, b: Player) -> bool:
			return a.peer_id < b.peer_id
		)
	round_number = int(state.get("round_number", round_number))
	current_player_index = int(state.get("current_player_index", current_player_index))
	current_player_peer_id = int(state.get("current_player_peer_id", -1))
	starting_player_index = int(state.get("starting_player_index", starting_player_index))
	claim_window_active = bool(state.get("claim_window_active", false))
	claim_deadline_unix = int(state.get("claim_deadline_unix", 0))
	claim_opened_by_peer_id = int(state.get("claim_opened_by_peer_id", -1))
	turn_pickup_completed = bool(state.get("turn_pickup_completed", false))
	turn_discard_completed = bool(state.get("turn_discard_completed", false))
	player_put_down_status.clear()
	player_put_down_progress.clear()
	player_put_down_buffer.clear()
	player_put_down_group_buffer.clear()
	player_committed_melds.clear()
	public_melds_data.clear()
	for pid in players.keys():
		player_put_down_status[pid] = false
		player_put_down_progress[pid] = _build_default_put_down_progress()
		player_put_down_buffer[pid] = []
		player_put_down_group_buffer[pid] = []
		player_committed_melds[pid] = []
	var put_down_ids: Array = state.get("put_down_player_ids", [])
	for put_down_id_raw in put_down_ids:
		var put_down_id: int = int(put_down_id_raw)
		player_put_down_status[put_down_id] = true
	var put_down_progress_raw: Variant = state.get("put_down_progress", {})
	if typeof(put_down_progress_raw) == TYPE_DICTIONARY:
		var put_down_progress_dict: Dictionary = put_down_progress_raw
		for raw_peer_key in put_down_progress_dict.keys():
			var peer_id: int = int(raw_peer_key)
			var raw_progress: Variant = put_down_progress_dict[raw_peer_key]
			player_put_down_progress[peer_id] = _normalize_put_down_progress(raw_progress)
	var public_melds_raw: Variant = state.get("public_melds", [])
	if typeof(public_melds_raw) == TYPE_ARRAY:
		var public_melds_array: Array = public_melds_raw
		for raw_meld in public_melds_array:
			if typeof(raw_meld) != TYPE_DICTIONARY:
				continue
			var meld_data: Dictionary = (raw_meld as Dictionary).duplicate(true)
			var owner_peer_id: int = int(meld_data.get("owner_peer_id", -1))
			if owner_peer_id >= 0:
				var owner_melds_variant: Variant = player_committed_melds.get(owner_peer_id, [])
				var owner_melds: Array = []
				if typeof(owner_melds_variant) == TYPE_ARRAY:
					owner_melds = owner_melds_variant
				owner_melds.append(meld_data)
				player_committed_melds[owner_peer_id] = owner_melds
			public_melds_data.append(meld_data)
	var round_requirement_raw: Variant = state.get("round_requirement", {})
	current_round_requirement_data.clear()
	if typeof(round_requirement_raw) == TYPE_DICTIONARY:
		var round_requirement_dict: Dictionary = round_requirement_raw
		if not round_requirement_dict.is_empty():
			current_round_requirement_data = {
				"round": int(round_requirement_dict.get("round", round_number)),
				"sets_of_3": int(round_requirement_dict.get("sets_of_3", 0)),
				"runs_of_4": int(round_requirement_dict.get("runs_of_4", 0)),
				"runs_of_7": int(round_requirement_dict.get("runs_of_7", 0)),
				"all_cards": bool(round_requirement_dict.get("all_cards", false))
			}
	var discard_top_data: Variant = state.get("discard_top", {})
	discard_pile.clear()
	if typeof(discard_top_data) == TYPE_DICTIONARY:
		var discard_dict: Dictionary = discard_top_data
		if not discard_dict.is_empty():
			discard_pile.append(Card.from_dict(discard_dict))
	if current_player_peer_id == -1:
		_refresh_current_player_peer_id()
	if TURN_DEBUG:
		print("[TURN_DEBUG][GM][apply_state] local_peer=%s round=%d current_idx=%d current_peer=%s starting_idx=%d order_size=%d order_peer_ids=%s" % [
			str(multiplayer.get_unique_id()),
			round_number,
			current_player_index,
			str(current_player_peer_id),
			starting_player_index,
			player_order.size(),
			str(_player_order_peer_ids())
		])
	if ProjectSettings.get_setting(SNAPSHOT_LOG_SETTING_PATH, false):
		print("Applied game state snapshot. Players: %d Round: %d Current idx: %d" % [players.size(), round_number, current_player_index])

func serialize_hand_for_peer(peer_id: int) -> Array:
	var result: Array = []
	var key: Variant = peer_id
	if not player_hands.has(key):
		for existing_key in player_hands.keys():
			if int(existing_key) == int(peer_id):
				key = existing_key
				break
	if not player_hands.has(key):
		_log_game("No private hand found for peer %s. Known keys: %s" % [str(peer_id), str(player_hands.keys())])
		return result
	for card in player_hands[key]:
		if card is Card:
			result.append(card.to_dict())
	return result

func apply_private_hand(cards_data: Array) -> void:
	if _is_server_authority():
		return
	var my_peer_id: int = multiplayer.get_unique_id()
	var cards: Array = []
	for c in cards_data:
		if typeof(c) == TYPE_DICTIONARY:
			cards.append(Card.from_dict(c))
	player_hands[my_peer_id] = cards
	print("Client peer %s received private hand with %d cards." % [str(my_peer_id), cards.size()])

func apply_private_put_down_buffer(cards_data: Array) -> void:
	if _is_server_authority():
		return
	private_put_down_buffer_data.clear()
	for raw in cards_data:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		private_put_down_buffer_data.append((raw as Dictionary).duplicate(true))

func get_private_put_down_buffer() -> Array:
	if _is_server_authority():
		var local_peer_id: int = multiplayer.get_unique_id()
		return get_put_down_buffer_for_peer(local_peer_id)
	return private_put_down_buffer_data.duplicate(true)

func _extract_peer_id_from_player_entry(player_entry: Variant) -> int:
	if player_entry is Player:
		return (player_entry as Player).peer_id
	if typeof(player_entry) == TYPE_DICTIONARY and player_entry.has("peer_id"):
		return int(player_entry["peer_id"])
	return -1

func _refresh_current_player_peer_id() -> void:
	if player_order.is_empty():
		current_player_peer_id = -1
		return
	var safe_index: int = clampi(current_player_index, 0, player_order.size() - 1)
	var player_entry: Variant = player_order[safe_index]
	current_player_peer_id = _extract_peer_id_from_player_entry(player_entry)

func _player_order_peer_ids() -> Array:
	var ids: Array = []
	for entry in player_order:
		var pid: int = _extract_peer_id_from_player_entry(entry)
		ids.append(pid)
	return ids

func _sync_put_down_status_for_players() -> void:
	var next_status: Dictionary = {}
	var next_progress: Dictionary = {}
	var next_buffer: Dictionary = {}
	var next_group_buffer: Dictionary = {}
	var next_committed_melds: Dictionary = {}
	for pid in players.keys():
		next_status[pid] = bool(player_put_down_status.get(pid, false))
		next_progress[pid] = _normalize_put_down_progress(player_put_down_progress.get(pid, _build_default_put_down_progress()))
		next_buffer[pid] = get_put_down_buffer_for_peer(pid)
		next_group_buffer[pid] = get_put_down_group_buffer_for_peer(pid)
		var existing_melds_variant: Variant = player_committed_melds.get(pid, [])
		if typeof(existing_melds_variant) == TYPE_ARRAY:
			next_committed_melds[pid] = (existing_melds_variant as Array).duplicate(true)
		else:
			next_committed_melds[pid] = []
	player_put_down_status = next_status
	player_put_down_progress = next_progress
	player_put_down_buffer = next_buffer
	player_put_down_group_buffer = next_group_buffer
	player_committed_melds = next_committed_melds
	if _is_server_authority():
		public_melds_data = serialize_public_melds()

func _build_default_put_down_progress() -> Dictionary:
	return {
		"sets_done": 0,
		"runs4_done": 0,
		"runs7_done": 0,
		"set_numbers": [],
		"run_suits": [],
		"run4_suits": [],
		"run7_suits": []
	}

func _normalize_put_down_progress(raw_progress: Variant) -> Dictionary:
	var progress: Dictionary = _build_default_put_down_progress()
	if typeof(raw_progress) != TYPE_DICTIONARY:
		return progress
	var progress_dict: Dictionary = raw_progress
	progress["sets_done"] = maxi(0, int(progress_dict.get("sets_done", 0)))
	progress["runs4_done"] = maxi(0, int(progress_dict.get("runs4_done", 0)))
	progress["runs7_done"] = maxi(0, int(progress_dict.get("runs7_done", 0)))
	progress["set_numbers"] = _to_int_array(progress_dict.get("set_numbers", []))
	progress["run_suits"] = _to_int_array(progress_dict.get("run_suits", []))
	progress["run4_suits"] = _to_int_array(progress_dict.get("run4_suits", []))
	progress["run7_suits"] = _to_int_array(progress_dict.get("run7_suits", []))
	return progress

func _to_int_array(values: Variant) -> Array[int]:
	var result: Array[int] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	var raw_array: Array = values
	for raw in raw_array:
		result.append(int(raw))
	return result

func _ensure_client_state_binding() -> void:
	var gsm: GameStateManager = Game_State_Manager
	if gsm == null:
		_client_state_bind_attempts += 1
		if _client_state_bind_attempts < CLIENT_STATE_BIND_MAX_ATTEMPTS:
			call_deferred("_ensure_client_state_binding")
		elif TURN_DEBUG:
			print("[TURN_DEBUG][GM][bind_state] failed to find Game_State_Manager after %d attempts" % _client_state_bind_attempts)
		return

	if not gsm.game_state_updated.is_connected(apply_game_state):
		gsm.game_state_updated.connect(apply_game_state)
	if TURN_DEBUG:
		print("[TURN_DEBUG][GM][bind_state] connected game_state_updated (attempt=%d local_peer=%s server=%s)" % [
			_client_state_bind_attempts,
			str(multiplayer.get_unique_id()),
			str(multiplayer.is_server() or OS.has_feature("server"))
		])

func _resolve_hand_key_for_peer(peer_id: int) -> Variant:
	var key: Variant = peer_id
	if player_hands.has(key):
		return key
	for existing_key in player_hands.keys():
		if int(existing_key) == int(peer_id):
			return existing_key
	return null

func _card_signature_for_card(card: Card) -> String:
	if card == null:
		return ""
	return "%d|%d|%d" % [int(card.suit), card.number, card.point_value]

func _card_signature_from_dict(card_data: Dictionary) -> String:
	if card_data.is_empty():
		return ""
	var suit: int = int(card_data.get("suit", -1))
	var number: int = int(card_data.get("number", -1))
	var point_value: int = int(card_data.get("point_value", -1))
	if suit < 0 or number < 0 or point_value < 0:
		return ""
	return "%d|%d|%d" % [suit, number, point_value]
