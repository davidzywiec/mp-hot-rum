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

func _ready() -> void:
	if not multiplayer.is_server() and not OS.has_feature("server"):
		queue_free()
		return


#Load ruleset from file
func start_game(ruleset_path : String = "res://data/rulesets/default_ruleset.json") -> void:
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
	deck = Deck.new(players)
	print("Deck created for %d players." % players)

#Create hand for each player based on the hand count for that round
func deal_hand(round: int) -> void:
	pass #TODO: deal hands to players at round start

func reset_hands() -> void:
	pass #TODO: reset player hands at round start

func get_player_name(index: int) -> String:
	var peer_id = player_order[index].peer_id
	if players.has(peer_id):
		return players[peer_id].name
	
	return "unknown"

func load_players(player_data: Dictionary) -> void:
	players = player_data
	player_order = []
	for pid in players.keys():
		player_order.append(players[pid])
	for x in players.keys():
		print("GameManager Loaded player: %s" % players[x].name)

func increment_starting_player() -> void:
	starting_player_index = (starting_player_index + 1) % player_order.size()
	current_player_index = starting_player_index
	print("Starting player changed to index %d (%s)" % [starting_player_index, get_player_name(starting_player_index)])

func advance_to_next_player() -> void:
	current_player_index = (current_player_index + 1) % player_order.size()
	print("Current player advanced to index %d (%s)" % [current_player_index, get_player_name(current_player_index)])

func advance_to_next_round() -> void:
	round_number += 1
	print("Advancing to round %d" % round_number)
	SignalManager.round_updated.emit(round_number, get_player_name(current_player_index))
	reset_hands()
	deal_hand(round_number)
