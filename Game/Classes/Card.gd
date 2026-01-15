# Card.gd
class_name Card
extends RefCounted
# RefCounted is ideal for lightweight data objects

enum Suit {
	HEARTS,
	DIAMONDS,
	CLUBS,
	SPADES
}

var suit: Suit
var number: int
var point_value: int

func _init(p_suit: Suit, p_number: int, p_point_value: int) -> void:
	suit = p_suit
	number = p_number
	point_value = p_point_value

func to_string() -> String:
	return "%s-%d (%d pts)" % [Suit.keys()[suit], number, point_value]
