extends Node

var host_flag : bool = false
var deck : Deck
var ruleset : Ruleset
# Player registries
var players: Dictionary = {} # key: peer_id, value: player_data
var player_order : Array = [] # ordered list of peer_ids for turn management
var player_hands : Dictionary = {} # key: peer_id, value: Array of Cards
var current_player_index : int = 0
var starting_player_index : int = 0
var round_number : int = 1

const GAME_LOG_SETTING_PATH: String = "debug/game_logs"
const SNAPSHOT_LOG_SETTING_PATH: String = "debug/snapshot_logs"

func _log_game(msg: String) -> void:
	if not ProjectSettings.get_setting(GAME_LOG_SETTING_PATH, true):
		return
	print(msg)

func _is_server_authority() -> bool:
	return multiplayer.is_server() or OS.has_feature("server")

func _ready() -> void:
	if not multiplayer.is_server() and not OS.has_feature("server"):
		# Keep the singleton alive on clients for UI/state reads,
		# but avoid running server-only logic.
		if Game_State_Manager:
			Game_State_Manager.game_state_updated.connect(apply_game_state)
		return

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

func get_player_name(index: int) -> String:
	if player_order.is_empty():
		return "unknown"

	var safe_index: int = clampi(index, 0, player_order.size() - 1)
	var player_entry: Variant = player_order[safe_index]
	var peer_id: int = -1

	if player_entry is Player:
		peer_id = (player_entry as Player).peer_id
	elif typeof(player_entry) == TYPE_DICTIONARY and player_entry.has("peer_id"):
		peer_id = int(player_entry["peer_id"])
	else:
		return "unknown"

	if players.has(peer_id):
		var player_data: Variant = players[peer_id]
		if player_data is Player:
			return (player_data as Player).name
		if typeof(player_data) == TYPE_DICTIONARY and player_data.has("name"):
			return str(player_data["name"])
	return "unknown"

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

func _deal_count_for_round(round: int) -> int:
	if ruleset == null:
		return 7
	var req: Variant = ruleset.get_round(round)
	if req == null:
		return 7
	var count: int = int(req.deal_count)
	return 7 if count <= 0 else count

func _apply_debug_start_round() -> void:
	var configured_round: int = int(ProjectSettings.get_setting("debug/start_round", 1))
	var max_rounds: int = int(ruleset.max_rounds) if ruleset != null else 1
	if max_rounds <= 0:
		max_rounds = 1
	round_number = clamp(configured_round, 1, max_rounds)
	current_player_index = 0
	starting_player_index = 0
	_log_game("Starting game at round %d (debug/start_round=%d)." % [round_number, configured_round])

func increment_starting_player() -> void:
	if not _is_server_authority():
		return
	starting_player_index = (starting_player_index + 1) % player_order.size()
	current_player_index = starting_player_index
	_log_game("Starting player changed to index %d (%s)" % [starting_player_index, get_player_name(starting_player_index)])

func advance_to_next_player() -> void:
	if not _is_server_authority():
		return
	current_player_index = (current_player_index + 1) % player_order.size()
	_log_game("Current player advanced to index %d (%s)" % [current_player_index, get_player_name(current_player_index)])

func advance_to_next_round() -> void:
	if not _is_server_authority():
		return
	round_number += 1
	_log_game("Advancing to round %d" % round_number)
	SignalManager.round_updated.emit(round_number, get_player_name(current_player_index))
	reset_hands()
	deal_hand(round_number)

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
		player.peer_id = p.get("peer_id")
		player.name = p.get("name", "")
		player.ready = p.get("ready", false)
		player.current_phase = p.get("current_phase", 1)
		player.score = p.get("score", 0)
		new_players[player.peer_id] = player
	players = new_players
	player_order = []
	if order_ids.size() > 0:
		for pid in order_ids:
			if players.has(pid):
				player_order.append(players[pid])
	else:
		for p in players.values():
			player_order.append(p)
	round_number = int(state.get("round_number", round_number))
	current_player_index = int(state.get("current_player_index", current_player_index))
	starting_player_index = int(state.get("starting_player_index", starting_player_index))
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
