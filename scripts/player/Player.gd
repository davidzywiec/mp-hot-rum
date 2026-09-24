# Player.gd
extends Resource
class_name Player

var peer_id: int = 0
var name: String
var ready: bool = false
var is_ai: bool = false
var difficulty: String = ""
var cards : Array = [] # could later be changed to Array[Card]
var current_phase: int = 1
var score: int = 0


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"name": name,
		"ready": ready,
		"is_ai": is_ai,
		"difficulty": difficulty,
		"cards": cards,
		"current_phase": current_phase,
		"score": score
	}

func to_public_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"name": name,
		"ready": ready,
		"is_ai": is_ai,
		"difficulty": difficulty,
		"current_phase": current_phase,
		"score": score
	}
