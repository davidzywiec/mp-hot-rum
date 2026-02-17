# Deck.gd
class_name Deck
extends RefCounted

var cards: Array[Card] = []

func _init(players_count: int) -> void:
	
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
			var points: int = 0
			if number == 1:
				points = 15
			elif number == 2:
				points = 20
			elif number > 10:
				points = 5
			else:
				points = 10
			
			add_card_to_bottom(Card.new(suit, number, points))
			
func deal_hand(card_count: int) -> Array[Card]:
	var hand: Array[Card] = []
	for _i in range(card_count):
		var card: Card = draw_card()
		if card == null:
			break
		hand.append(card)
	return hand
