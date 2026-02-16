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

func _to_string() -> String:
	return "%s-%d (%d pts)" % [Suit.keys()[suit], number, point_value]

func to_dict() -> Dictionary:
	return {
		"suit": int(suit),
		"number": number,
		"point_value": point_value
	}

static func from_dict(data: Dictionary) -> Card:
	return Card.new(
		int(data.get("suit", 0)),
		int(data.get("number", 1)),
		int(data.get("point_value", 0))
	)
