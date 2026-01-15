# Deck.gd
class_name Deck
extends RefCounted

var cards: Array[Card] = []

func _init(initial_cards: Array[Card] = []) -> void:
	cards = initial_cards.duplicate()

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
