extends Control

@onready var round_number_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/RoundNumberContainer/RoundNumber
@onready var current_player_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/CurrentPlayerContainer/CurrentPlayer

func _ready() -> void:
	SignalManager.round_updated.connect(update_round_ui)
	Game_State_Manager.game_state_updated.connect(_on_game_state_updated)
	if multiplayer.is_server() or OS.has_feature("server"):
		pull_round_ui()

func _on_game_state_updated(_state: Dictionary) -> void:
	pull_round_ui()

func pull_round_ui() -> void:
	var round = GameManager.round_number
	var current_player_name = GameManager.get_player_name(GameManager.current_player_index)
	update_round_ui(round, current_player_name)


func update_round_ui(round: int, current_player_name: String) -> void:
	print("Updating round UI: Round %d, Current Player: %s" % [round, current_player_name])
	round_number_label.clear()
	round_number_label.parse_bbcode("[b]Round: [/b]%d" % round)
	
	current_player_label.clear()
	current_player_label.parse_bbcode("[b]Current Player: [/b]%s" % current_player_name)
