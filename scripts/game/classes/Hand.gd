# Hand.gd
class_name Hand
extends RefCounted

var cards: Array[Card] = []

func add_card(card: Card) -> void:
	cards.append(card)

func remove_card(card: Card) -> bool:
	if cards.has(card):
		cards.erase(card)
		return true
	return false

func clear() -> void:
	cards.clear()

func sort_by_suit_then_number() -> void:
	cards.sort_custom(func(a: Card, b: Card) -> bool:
		if a.suit == b.suit:
			return a.number < b.number
		return a.suit < b.suit
	)

func sort_by_number_then_suit() -> void:
	cards.sort_custom(func(a: Card, b: Card) -> bool:
		if a.number == b.number:
			return a.suit < b.suit
		return a.number < b.number
	)

func get_total_points() -> int:
	var total: int = 0
	for card in cards:
		total += card.point_value
	return total
