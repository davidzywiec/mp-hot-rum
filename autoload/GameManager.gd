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

func get_hand_size_for_peer(peer_id: int) -> int:
	var hand_key: Variant = _resolve_hand_key_for_peer(peer_id)
	if hand_key == null:
		return 0
	if not player_hands.has(hand_key):
		return 0
	var hand_cards: Array = player_hands[hand_key]
	return hand_cards.size()

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
