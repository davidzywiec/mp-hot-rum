extends RefCounted
class_name AIPlayerStrategy

func choose_action(observation: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	if bool(observation.get("claim_window_active", false)):
		if int(observation.get("claim_offer_peer_id", -1)) != int(observation.get("peer_id", 0)):
			return {}
		return choose_claim(observation, random)
	if int(observation.get("current_player_peer_id", 0)) != int(observation.get("peer_id", -1)):
		return {}
	if not bool(observation.get("turn_pickup_completed", false)):
		return choose_pickup(observation, random)
	var hand: Array = observation.get("own_hand", [])
	if hand.is_empty():
		return {}
	var put_down_plan: Array = observation.get("put_down_plan", [])
	if not put_down_plan.is_empty():
		return {"type": "put_down", "cards_data": put_down_plan[0]}
	var add_actions: Array = observation.get("add_to_meld_actions", [])
	if not add_actions.is_empty():
		return add_actions[0]
	var card: Dictionary = choose_discard(observation, random)
	return {"type": "discard_card", "card_data": card}

func choose_pickup(observation: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var discard_top: Dictionary = observation.get("discard_top", {})
	if not discard_top.is_empty() and (int(observation.get("deck_count", 0)) <= 0 or random.randf() < 0.25):
		return {"type": "take_from_pile"}
	if int(observation.get("deck_count", 0)) > 0:
		return {"type": "draw_from_deck"}
	return {}

func choose_claim(observation: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var discard_top: Dictionary = observation.get("discard_top", {})
	if not discard_top.is_empty() and random.randf() < 0.3:
		return {"type": "claim_pile"}
	return {"type": "pass_claim"}

func choose_discard(observation: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var hand: Array = observation.get("own_hand", [])
	return hand[random.randi_range(0, hand.size() - 1)]
