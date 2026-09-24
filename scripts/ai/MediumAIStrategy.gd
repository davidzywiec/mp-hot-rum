extends AIPlayerStrategy
class_name MediumAIStrategy

func choose_pickup(observation: Dictionary, _random: RandomNumberGenerator) -> Dictionary:
	var discard_top: Dictionary = observation.get("discard_top", {})
	var deck_count: int = int(observation.get("deck_count", 0))
	if not discard_top.is_empty():
		var usefulness: float = card_usefulness(discard_top, observation.get("own_hand", []), observation.get("round_requirement", {}), observation.get("heuristic_weights", {}))
		usefulness += _opponent_interest(discard_top, observation) * _weight(observation, "opponent_risk") * 0.5
		if deck_count <= 0 or usefulness >= 6.0:
			return {"type": "take_from_pile"}
	if deck_count > 0:
		return {"type": "draw_from_deck"}
	return {}

func choose_discard(observation: Dictionary, _random: RandomNumberGenerator) -> Dictionary:
	var hand: Array = observation.get("own_hand", [])
	var best_card: Dictionary = hand[0]
	var best_score: float = -INF
	for raw_card in hand:
		var card: Dictionary = raw_card
		var remaining: Array = hand.duplicate()
		remaining.erase(raw_card)
		var score: float = hand_potential(remaining, observation)
		score -= _opponent_interest(card, observation) * _weight(observation, "opponent_risk")
		if score > best_score:
			best_card = card
			best_score = score
	return best_card

func hand_potential(hand: Array, observation: Dictionary) -> float:
	var requirement: Dictionary = observation.get("round_requirement", {})
	var progress: Dictionary = observation.get("put_down_progress", {})
	var set_weight: float = _weight(observation, "set")
	var run_weight: float = _weight(observation, "run")
	var wild_weight: float = _weight(observation, "wild")
	var point_weight: float = _weight(observation, "point_risk")
	var sets_needed: int = maxi(0, int(requirement.get("sets_of_3", 0)) - int(progress.get("sets_done", 0)))
	var runs4_needed: int = maxi(0, int(requirement.get("runs_of_4", 0)) - int(progress.get("runs4_done", 0)))
	var runs7_needed: int = maxi(0, int(requirement.get("runs_of_7", 0)) - int(progress.get("runs7_done", 0)))
	var rank_counts: Dictionary = {}
	var wild_count: int = 0
	var score: float = 0.0
	for raw_card in hand:
		var card: Dictionary = raw_card
		var number: int = int(card.get("number", 0))
		score -= float(card.get("point_value", 0)) * 0.08 * point_weight
		if number == 2:
			wild_count += 1
		else:
			rank_counts[number] = int(rank_counts.get(number, 0)) + 1
	var set_scores: Array[float] = []
	for count in rank_counts.values():
		var rank_count: int = int(count)
		set_scores.append(18.0 if rank_count >= 3 else (7.0 if rank_count == 2 else 1.5))
	set_scores.sort()
	set_scores.reverse()
	for index in range(mini(sets_needed, set_scores.size())):
		score += set_scores[index] * set_weight
	var used_suits: Array[int] = []
	for run_size in [7, 4]:
		var runs_needed: int = runs7_needed if run_size == 7 else runs4_needed
		for slot in range(runs_needed):
			var best_suit: int = -1
			var best_coverage: int = -1
			for suit in range(4):
				if used_suits.has(suit):
					continue
				var coverage: int = _best_run_coverage(hand, suit, run_size)
				if coverage > best_coverage:
					best_coverage = coverage
					best_suit = suit
			if best_suit >= 0:
				used_suits.append(best_suit)
				score += float(best_coverage * best_coverage) * (2.5 if run_size == 7 else 3.0) * run_weight
	score += float(mini(wild_count, sets_needed * 2 + runs4_needed * 3 + runs7_needed * 6)) * 8.0 * wild_weight
	return score

func _best_run_coverage(hand: Array, suit: int, run_size: int) -> int:
	var numbers: Dictionary = {}
	for raw_card in hand:
		var card: Dictionary = raw_card
		if int(card.get("suit", -1)) == suit and int(card.get("number", 0)) != 2:
			numbers[int(card.get("number", 0))] = true
	var best: int = 0
	for start in range(1, 15 - run_size):
		var coverage: int = 0
		for number in range(start, start + run_size):
			if numbers.has(number):
				coverage += 1
		best = maxi(best, coverage)
	return best

func choose_claim(observation: Dictionary, _random: RandomNumberGenerator) -> Dictionary:
	var discard_top: Dictionary = observation.get("discard_top", {})
	if not discard_top.is_empty() and card_usefulness(discard_top, observation.get("own_hand", []), observation.get("round_requirement", {}), observation.get("heuristic_weights", {})) >= 8.0:
		return {"type": "claim_pile"}
	return {"type": "pass_claim"}

func card_usefulness(card: Dictionary, hand: Array, requirement: Dictionary, weights: Dictionary = {}) -> float:
	var number: int = int(card.get("number", 0))
	var suit: int = int(card.get("suit", -1))
	var score: float = -float(card.get("point_value", 0)) * 0.12 * float(weights.get("point_risk", 1.0))
	if number == 2:
		return score + 12.0 * float(weights.get("wild", 1.0))
	var sets_needed: int = int(requirement.get("sets_of_3", 0))
	var runs_needed: int = int(requirement.get("runs_of_4", 0)) + int(requirement.get("runs_of_7", 0))
	for raw_other in hand:
		var other: Dictionary = raw_other
		var other_number: int = int(other.get("number", 0))
		if other_number == 2:
			score += 2.0 * float(weights.get("wild", 1.0))
		elif sets_needed > 0 and other_number == number:
			score += 4.5 * float(weights.get("set", 1.0))
		if runs_needed > 0 and int(other.get("suit", -1)) == suit:
			var distance: int = absi(other_number - number)
			if distance == 1:
				score += 3.0 * float(weights.get("run", 1.0))
			elif distance == 2:
				score += 1.0 * float(weights.get("run", 1.0))
	return score

func _weight(observation: Dictionary, name: String) -> float:
	var weights: Dictionary = observation.get("heuristic_weights", {})
	return float(weights.get(name, 1.0))

func _opponent_interest(card: Dictionary, observation: Dictionary) -> float:
	var history: Array = observation.get("public_card_history", [])
	var own_peer_id: int = int(observation.get("peer_id", -1))
	for index in range(history.size() - 1, maxi(-1, history.size() - 21), -1):
		var event: Dictionary = history[index]
		var event_type: String = str(event.get("event", ""))
		if not ["claim", "take_discard", "discard"].has(event_type):
			continue
		if int(event.get("peer_id", -1)) == own_peer_id:
			continue
		var known_card: Dictionary = event.get("card", {})
		if int(known_card.get("number", 0)) == int(card.get("number", -1)):
			return -2.0 if event_type == "discard" else 4.0
		elif int(known_card.get("suit", -1)) == int(card.get("suit", -2)) and absi(int(known_card.get("number", 0)) - int(card.get("number", 0))) <= 2:
			return -1.0 if event_type == "discard" else 2.0
	return 0.0
