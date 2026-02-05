extends Node

var host_flag : bool = false
var deck
var ruleset : Ruleset
#Player registries
var players = {} # key: peer_id, value: player_data
var player_order : Array = [] # ordered list of peer_ids for turn management
var player_hands : Dictionary = {} # key: peer_id, value: Array of Cards
var current_player_index : int = 0
var starting_player_index : int = 0
var round_number : int = 1

const DEBUG_SETTING_PATH := "debug/network_debug"

func _is_server_authority() -> bool:
	return multiplayer.is_server() or OS.has_feature("server")

func _ready() -> void:
	if not multiplayer.is_server() and not OS.has_feature("server"):
		# Keep the singleton alive on clients for UI/state reads,
		# but avoid running server-only logic.
		if Game_State_Manager:
			Game_State_Manager.game_state_updated.connect(apply_game_state)
		return


#Load ruleset from file
func start_game(ruleset_path : String = "res://data/rulesets/default_ruleset.json") -> void:
	if not _is_server_authority():
		return
	var ruleset_loader := RulesetLoader.new()
	var loaded_ruleset := ruleset_loader.load_ruleset(ruleset_path)
	if loaded_ruleset != null:
		ruleset = loaded_ruleset
		create_deck(players.size())
		SignalManager.round_updated.emit(round_number, get_player_name(starting_player_index))

	else:
		printerr("Error loading ruleset: %s" % ruleset_loader.last_error)


#Create deck for the players based on player count
func create_deck(players: int) -> void:
	if not _is_server_authority():
		return
	deck = Deck.new(players)
	print("Deck created for %d players." % players)

#Create hand for each player based on the hand count for that round
func deal_hand(round: int) -> void:
	if not _is_server_authority():
		return
	pass #TODO: deal hands to players at round start

func reset_hands() -> void:
	if not _is_server_authority():
		return
	pass #TODO: reset player hands at round start

func get_player_name(index: int) -> String:
	var peer_id = player_order[index].peer_id
	if players.has(peer_id):
		return players[peer_id].name
	
	return "unknown"

func load_players(player_data: Dictionary) -> void:
	if not _is_server_authority():
		return
	players = player_data
	_rebuild_player_order()
	for x in players.keys():
		print("GameManager Loaded player: %s" % players[x].name)

func _rebuild_player_order() -> void:
	player_order = []
	var ids := players.keys()
	ids.sort()
	for pid in ids:
		player_order.append(players[pid])

func increment_starting_player() -> void:
	if not _is_server_authority():
		return
	starting_player_index = (starting_player_index + 1) % player_order.size()
	current_player_index = starting_player_index
	print("Starting player changed to index %d (%s)" % [starting_player_index, get_player_name(starting_player_index)])

func advance_to_next_player() -> void:
	if not _is_server_authority():
		return
	current_player_index = (current_player_index + 1) % player_order.size()
	print("Current player advanced to index %d (%s)" % [current_player_index, get_player_name(current_player_index)])

func advance_to_next_round() -> void:
	if not _is_server_authority():
		return
	round_number += 1
	print("Advancing to round %d" % round_number)
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
	var new_players := {}
	for p in players_array:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var player = Player.new()
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
	if ProjectSettings.get_setting(DEBUG_SETTING_PATH, false):
		print("📥 Applied game state snapshot. Players:", players.size(), "Round:", round_number, "Current idx:", current_player_index)
