extends RefCounted
class_name PutDownValidator

const GROUP_SET_3: String = "set3"
const GROUP_RUN_4: String = "run4"
const GROUP_RUN_7: String = "run7"

static func validate_single_group(selected_cards: Array[Card], requirement: RoundRequirement, progress: Dictionary) -> Dictionary:
	if requirement == null:
		return {
			"ok": false,
			"reason": "No round requirements found."
		}

	var sets_required: int = maxi(0, int(requirement.sets_of_3))
	var runs4_required: int = maxi(0, int(requirement.runs_of_4))
	var runs7_required: int = maxi(0, int(requirement.runs_of_7))
	var selected_count: int = int(selected_cards.size())
	if selected_count == 0:
		return {
			"ok": false,
			"reason": "No cards selected for put down."
		}

	var sets_done: int = int(progress.get("sets_done", 0))
	var runs4_done: int = int(progress.get("runs4_done", 0))
	var runs7_done: int = int(progress.get("runs7_done", 0))
	var sets_left: int = maxi(0, sets_required - sets_done)
	var runs4_left: int = maxi(0, runs4_required - runs4_done)
	var runs7_left: int = maxi(0, runs7_required - runs7_done)
	if sets_left <= 0 and runs4_left <= 0 and runs7_left <= 0:
		return {
			"ok": false,
			"reason": "All put-down slots are already filled."
		}

	var used_set_numbers: Array[int] = _to_int_array(progress.get("set_numbers", []))
	var used_run_suits: Array[int] = _to_int_array(progress.get("run_suits", []))
	var min_required_cards: int = 99
	if sets_left > 0:
		min_required_cards = mini(min_required_cards, 3)
	if runs4_left > 0:
		min_required_cards = mini(min_required_cards, 4)
	if runs7_left > 0:
		min_required_cards = mini(min_required_cards, 7)
	if selected_count < min_required_cards:
		return {
			"ok": false,
			"reason": "Selected meld is too small. Remaining slots need at least %d cards." % min_required_cards
		}

	var candidates: Array[Dictionary] = []
	var set_validation: Dictionary = {}
	if sets_left > 0 and selected_count >= 3:
		set_validation = validate_set_cards(selected_cards)
		if bool(set_validation.get("ok", false)):
			var set_number: int = int(set_validation.get("set_number", -1))
			if not used_set_numbers.has(set_number):
				candidates.append({
					"ok": true,
					"reason": "",
					"group_type": GROUP_SET_3,
					"set_number": set_number,
					"run_suit": -1
				})

	var has_run_validation: bool = false
	var run_validation: Dictionary = {}
	if (runs4_left > 0 and selected_count >= 4) or (runs7_left > 0 and selected_count >= 7):
		has_run_validation = true
		run_validation = validate_run_cards(selected_cards)
		if bool(run_validation.get("ok", false)):
			var run_suit: int = int(run_validation.get("run_suit", -1))
			if not used_run_suits.has(run_suit):
				if runs7_left > 0 and selected_count >= 7:
					candidates.append({
						"ok": true,
						"reason": "",
						"group_type": GROUP_RUN_7,
						"set_number": -1,
						"run_suit": run_suit
					})
				if runs4_left > 0 and selected_count >= 4:
					candidates.append({
						"ok": true,
						"reason": "",
						"group_type": GROUP_RUN_4,
						"set_number": -1,
						"run_suit": run_suit
					})

	if candidates.is_empty():
		if sets_left > 0 and bool(set_validation.get("ok", false)):
			var duplicate_set_number: int = int(set_validation.get("set_number", -1))
			return {
				"ok": false,
				"reason": "You already put down a set with rank %s this round." % _rank_text(duplicate_set_number)
			}
		if has_run_validation and bool(run_validation.get("ok", false)):
			var duplicate_run_suit: int = int(run_validation.get("run_suit", -1))
			return {
				"ok": false,
				"reason": "You already put down a run in suit %s this round." % _suit_text(duplicate_run_suit)
			}
		return {
			"ok": false,
			"reason": "Selected cards do not match any remaining slot (set 3+, run 4+, run 7+)."
		}

	if candidates.size() == 1:
		return candidates[0]

	var run7_candidate: Dictionary = {}
	var found_set_candidate: bool = false
	for candidate in candidates:
		var group_type: String = str(candidate.get("group_type", ""))
		if group_type == GROUP_SET_3:
			found_set_candidate = true
		if group_type == GROUP_RUN_7:
			run7_candidate = candidate
	if not run7_candidate.is_empty() and not found_set_candidate:
		return run7_candidate

	return {
		"ok": false,
		"reason": "Selected cards match multiple slot types. Adjust selection to one clear meld."
	}

static func _validate_set_of_3(cards: Array[Card]) -> Dictionary:
	if cards.size() != 3:
		return {
			"ok": false,
			"reason": "A set must contain exactly 3 cards."
		}
	return validate_set_cards(cards)

static func _validate_run(cards: Array[Card], run_size: int) -> Dictionary:
	if cards.size() != run_size:
		return {
			"ok": false,
			"reason": "Run size mismatch."
		}
	return validate_run_cards(cards)

static func validate_set_cards(cards: Array[Card], required_number: int = -1) -> Dictionary:
	if cards.size() < 3:
		return {
			"ok": false,
			"reason": "A set must contain at least 3 cards."
		}
	var target_number: int = required_number
	for card in cards:
		if _is_wild(card):
			continue
		if target_number == -1:
			target_number = card.number
			continue
		if card.number != target_number:
			return {
				"ok": false,
				"reason": "Invalid set: non-wild cards must share the same rank."
			}
	if target_number == -1:
		return {
			"ok": false,
			"reason": "A set must include at least one non-wild card."
		}
	return {
		"ok": true,
		"reason": "",
		"set_number": target_number
	}

static func validate_run_cards(cards: Array[Card], required_suit: int = -1) -> Dictionary:
	var run_size: int = cards.size()
	if run_size < 3:
		return {
			"ok": false,
			"reason": "A run must contain at least 3 cards."
		}
	var natural_numbers: Array[int] = []
	var wild_count: int = 0
	var run_suit: int = required_suit
	for card in cards:
		if _is_wild(card):
			wild_count += 1
			continue
		if run_suit == -1:
			run_suit = int(card.suit)
		elif int(card.suit) != run_suit:
			return {
				"ok": false,
				"reason": "Invalid run: non-wild cards must be the same suit."
			}
		natural_numbers.append(card.number)
	if run_suit == -1:
		return {
			"ok": false,
			"reason": "A run must include at least one non-wild card."
		}
	natural_numbers.sort()
	for i in range(1, natural_numbers.size()):
		if natural_numbers[i] == natural_numbers[i - 1]:
			return {
				"ok": false,
				"reason": "Invalid run: duplicate card ranks are not allowed."
			}

	var min_start: int = 1
	var max_start: int = 14 - run_size
	if max_start < min_start:
		return {
			"ok": false,
			"reason": "Invalid run configuration."
		}

	for start in range(min_start, max_start + 1):
		var end_value: int = start + run_size - 1
		var all_fit_window: bool = true
		for number in natural_numbers:
			if number < start or number > end_value:
				all_fit_window = false
				break
		if not all_fit_window:
			continue
		var missing_count: int = run_size - natural_numbers.size()
		if missing_count <= wild_count:
			return {
				"ok": true,
				"reason": "",
				"run_suit": run_suit
			}

	return {
		"ok": false,
		"reason": "Invalid run: cards cannot form a consecutive sequence with wild cards."
	}

static func _to_int_array(values: Variant) -> Array[int]:
	var result: Array[int] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	var raw_array: Array = values
	for raw in raw_array:
		result.append(int(raw))
	return result

static func _is_wild(card: Card) -> bool:
	if card == null:
		return false
	return card.number == 2

static func _rank_text(number: int) -> String:
	match number:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		_:
			return str(number)

static func _suit_text(suit: int) -> String:
	match suit:
		Card.Suit.HEARTS:
			return "Hearts"
		Card.Suit.DIAMONDS:
			return "Diamonds"
		Card.Suit.CLUBS:
			return "Clubs"
		Card.Suit.SPADES:
			return "Spades"
		_:
			return "Unknown"
