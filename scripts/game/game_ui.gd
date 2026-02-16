extends Control

@onready var round_number_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/RoundNumberContainer/RoundNumber
@onready var current_player_label : RichTextLabel = $RoundDataContainer/MC/VBCRoundData/CurrentPlayerContainer/CurrentPlayer
@onready var hand_container: HBoxContainer = $RoundDataContainer/HandContainer
@onready var hand_title: Label = $RoundDataContainer/HandTitle

func _ready() -> void:
	SignalManager.round_updated.connect(update_round_ui)
	Game_State_Manager.game_state_updated.connect(_on_game_state_updated)
	Game_State_Manager.private_hand_updated.connect(_on_private_hand_updated)
	if multiplayer.is_server() or OS.has_feature("server"):
		pull_round_ui()
	_render_local_hand()

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

func _on_private_hand_updated(_cards: Array) -> void:
	_render_local_hand()

func _render_local_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	var my_peer_id := multiplayer.get_unique_id()
	if not GameManager.player_hands.has(my_peer_id):
		hand_title.text = "Your Hand (0)"
		return
	var cards: Array = GameManager.player_hands[my_peer_id]
	hand_title.text = "Your Hand (%d)" % cards.size()
	for c in cards:
		var label := Label.new()
		label.text = "%s-%d" % [Card.Suit.keys()[c.suit], c.number]
		hand_container.add_child(label)
