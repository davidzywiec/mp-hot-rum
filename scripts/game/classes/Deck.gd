# Deck.gd
class_name Deck
extends RefCounted

var cards: Array[Card] = []
var card_point_rules: CardPointRules = null

const DEFAULT_CARD_POINT_RULES_PATH: String = "res://data/scoring/default_card_point_rules.tres"

func _init(players_count: int, point_rules: CardPointRules = null) -> void:
	card_point_rules = point_rules
	if card_point_rules == null:
		var loaded_rules: Resource = load(DEFAULT_CARD_POINT_RULES_PATH)
		if loaded_rules is CardPointRules:
			card_point_rules = loaded_rules as CardPointRules
	
	#Get the number of decks needed on player count. 1 deck per 2 people.
	var loop_count: int = int(roundf(float(players_count) / 2.0))
	for _x in range(loop_count):
		build_deck()
	shuffle()

func shuffle() -> void:
	cards.shuffle()

func draw_card() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_front()

func add_card_to_bottom(card: Card) -> void:
	cards.append(card)

func add_card_to_top(card: Card) -> void:
	cards.push_front(card)

func clear() -> void:
	cards.clear()

func size() -> int:
	return cards.size()

func build_deck() -> void:
	# Build a standard deck
	for suit in Card.Suit.values():
		for number in range(1, 14):
			var points: int = _points_for_number(number)
			add_card_to_bottom(Card.new(suit, number, points))

func _points_for_number(number: int) -> int:
	if card_point_rules != null:
		return card_point_rules.get_points_for_number(number)
	if number == 1:
		return 15
	if number == 2:
		return 20
	if number >= 3 and number <= 9:
		return 5
	if number >= 10 and number <= 13:
		return 10
	return 0

func deal_hand(card_count: int) -> Array[Card]:
	var hand: Array[Card] = []
	for _i in range(card_count):
		var card: Card = draw_card()
		if card == null:
			break
		hand.append(card)
	return hand
