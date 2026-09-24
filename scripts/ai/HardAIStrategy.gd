extends MediumAIStrategy
class_name HardAIStrategy

# Hard look-ahead is bounded by the server's simulation budget. It samples only
# from unseen card identities in the observation, never the authoritative Deck.
func choose_pickup(observation: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var discard_top: Dictionary = observation.get("discard_top", {})
	var deck_count: int = int(observation.get("deck_count", 0))
	if discard_top.is_empty():
		return {"type": "draw_from_deck"} if deck_count > 0 else {}
	if deck_count <= 0:
		return {"type": "take_from_pile"}
	var hand: Array = observation.get("own_hand", [])
	var requirement: Dictionary = observation.get("round_requirement", {})
	var weights: Dictionary = observation.get("heuristic_weights", {})
	var known_value: float = card_usefulness(discard_top, hand, requirement, weights)
	known_value += _opponent_interest(discard_top, observation) * _weight(observation, "opponent_risk") * 0.5
	var unseen: Array = _unseen_cards(observation)
	if unseen.is_empty():
		return {"type": "take_from_pile"}
	var samples: int = clampi(int(observation.get("simulation_budget", 32)), 1, 256)
	var sampled_value: float = 0.0
	for index in range(samples):
		var drawn: Dictionary = unseen[random.randi_range(0, unseen.size() - 1)]
		sampled_value += card_usefulness(drawn, hand, requirement, weights)
	return {"type": "take_from_pile"} if known_value >= sampled_value / float(samples) else {"type": "draw_from_deck"}

func choose_discard(observation: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var hand: Array = observation.get("own_hand", [])
	var unseen: Array = _unseen_cards(observation)
	var samples: int = clampi(int(observation.get("simulation_budget", 32)), 1, 256)
	var best_card: Dictionary = hand[0]
	var best_score: float = -INF
	for raw_card in hand:
		var remaining: Array = hand.duplicate()
		remaining.erase(raw_card)
		var base_potential: float = hand_potential(remaining, observation)
		var score: float = base_potential - _opponent_interest(raw_card, observation) * _weight(observation, "opponent_risk")
		if not unseen.is_empty():
			var future_potential: float = 0.0
			for index in range(samples):
				var future_card: Dictionary = unseen[random.randi_range(0, unseen.size() - 1)]
				var future_hand: Array = remaining.duplicate()
				future_hand.append(future_card)
				future_potential += hand_potential(future_hand, observation) - base_potential
			score += future_potential / float(samples)
		if score > best_score:
			best_score = score
			best_card = raw_card
	return best_card

func _unseen_cards(observation: Dictionary) -> Array:
	var player_count: int = int(observation.get("player_count", 2))
	var deck_copies: int = maxi(1, int(observation.get("deck_copies", int(roundf(float(player_count) / 2.0)))))
	var point_values: Dictionary = observation.get("card_point_values", {})
	var unseen: Array = []
	for suit in range(4):
		for number in range(1, 14):
			for copy in range(deck_copies):
				unseen.append({"suit": suit, "number": number, "point_value": int(point_values.get(number, 0))})
	for raw_card in observation.get("own_hand", []):
		_remove_visible_card(unseen, raw_card)
	var discard_stack: Array = []
	for raw_event in observation.get("public_card_history", []):
		var event: Dictionary = raw_event
		match str(event.get("event", "")):
			"initial_discard", "replenish_discard", "discard":
				discard_stack.append(event.get("card", {}))
			"claim", "take_discard":
				if not discard_stack.is_empty():
					discard_stack.pop_back()
	if discard_stack.is_empty():
		var discard_top: Dictionary = observation.get("discard_top", {})
		if not discard_top.is_empty():
			discard_stack.append(discard_top)
	for raw_card in discard_stack:
		_remove_visible_card(unseen, raw_card)
	for raw_meld in observation.get("public_melds", []):
		for raw_card in (raw_meld as Dictionary).get("cards_data", []):
			_remove_visible_card(unseen, raw_card)
	return unseen

func _remove_visible_card(unseen: Array, visible: Dictionary) -> void:
	for index in range(unseen.size()):
		var card: Dictionary = unseen[index]
		if int(card.get("suit", -1)) == int(visible.get("suit", -2)) and int(card.get("number", 0)) == int(visible.get("number", -1)):
			unseen.remove_at(index)
			return
