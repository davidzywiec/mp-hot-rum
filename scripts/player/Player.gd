# Player.gd
extends Resource
class_name Player

var peer_id
var name: String
var ready: bool = false
var cards : Array = [] # could later be changed to Array[Card]
var current_phase: int = 1
var score: int = 0


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"name": name,
		"ready": ready,
		"cards": cards,
		"current_phase": current_phase,
		"score": score
	}

func to_public_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"name": name,
		"ready": ready,
		"current_phase": current_phase,
		"score": score
	}
