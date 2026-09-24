extends AIPlayerStrategy
class_name MediumAIStrategy

func choose_pickup(observation: Dictionary, _random: RandomNumberGenerator) -> Dictionary:
	var discard_top: Dictionary = observation.get("discard_top", {})
	var deck_count: int = int(observation.get("deck_count", 0))
	if not discard_top.is_empty():
		if deck_count <= 0 or card_usefulness(discard_top, observation.get("own_hand", []), observation.get("round_requirement", {})) >= 6.0:
			return {"type": "take_from_pile"}
	if deck_count > 0:
		return {"type": "draw_from_deck"}
	return {}

func choose_discard(observation: Dictionary, _random: RandomNumberGenerator) -> Dictionary:
	var hand: Array = observation.get("own_hand", [])
	var requirement: Dictionary = observation.get("round_requirement", {})
	var lowest: Dictionary = hand[0]
	var lowest_score: float = INF
	for raw_card in hand:
		var card: Dictionary = raw_card
		var other_cards: Array = hand.duplicate()
		other_cards.erase(raw_card)
		var score: float = card_usefulness(card, other_cards, requirement)
		if score < lowest_score:
			lowest = card
			lowest_score = score
	return lowest

func card_usefulness(card: Dictionary, hand: Array, requirement: Dictionary) -> float:
	var number: int = int(card.get("number", 0))
	var suit: int = int(card.get("suit", -1))
	var score: float = -float(card.get("point_value", 0)) * 0.12
	if number == 2:
		return score + 12.0
	var sets_needed: int = int(requirement.get("sets_of_3", 0))
	var runs_needed: int = int(requirement.get("runs_of_4", 0)) + int(requirement.get("runs_of_7", 0))
	for raw_other in hand:
		var other: Dictionary = raw_other
		var other_number: int = int(other.get("number", 0))
		if other_number == 2:
			score += 2.0
		elif sets_needed > 0 and other_number == number:
			score += 4.5
		if runs_needed > 0 and int(other.get("suit", -1)) == suit:
			var distance: int = absi(other_number - number)
			if distance == 1:
				score += 3.0
			elif distance == 2:
				score += 1.0
	return score
