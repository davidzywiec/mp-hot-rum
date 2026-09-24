extends RefCounted
class_name AIMeldPlanner

const SEARCH_BUDGET: int = 100000

static func find_plan(observation: Dictionary) -> Array:
	var requirement_data: Dictionary = observation.get("round_requirement", {})
	if requirement_data.is_empty():
		return []
	var requirement: RoundRequirement = RoundRequirement.new()
	requirement.sets_of_3 = int(requirement_data.get("sets_of_3", 0))
	requirement.runs_of_4 = int(requirement_data.get("runs_of_4", 0))
	requirement.runs_of_7 = int(requirement_data.get("runs_of_7", 0))
	requirement.all_cards = bool(requirement_data.get("all_cards", false))
	var progress: Dictionary = observation.get("put_down_progress", {}).duplicate(true)
	var hand: Array = (observation.get("own_hand", []) as Array).duplicate(true)
	var staged: Array = observation.get("staged_cards", [])
	for staged_card in staged:
		for i in range(hand.size()):
			if hand[i] == staged_card:
				hand.remove_at(i)
				break
	if _remaining_slots(requirement, progress) <= 0:
		return []
	var budget: Dictionary = {"left": SEARCH_BUDGET}
	var result: Dictionary = _search(hand, requirement, progress, budget)
	return result.get("groups", []) if bool(result.get("ok", false)) else []

static func _search(hand: Array, requirement: RoundRequirement, progress: Dictionary, budget: Dictionary) -> Dictionary:
	if _remaining_slots(requirement, progress) <= 0:
		if requirement.all_cards and not hand.is_empty():
			return {"ok": false}
		return {"ok": true, "groups": []}
	if hand.size() < _minimum_group_size(requirement, progress):
		return {"ok": false}
	if hand.size() > 32:
		return {"ok": false}
	for group_size in _candidate_group_sizes(hand, requirement, progress):
		var found: Dictionary = _search_combinations(hand, requirement, progress, budget, group_size, 0, [])
		if bool(found.get("ok", false)):
			return found
		if int(budget["left"]) <= 0:
			break
	return {"ok": false}

static func _candidate_group_sizes(hand: Array, requirement: RoundRequirement, progress: Dictionary) -> Array[int]:
	var sizes: Array[int] = []
	if requirement.all_cards:
		var minimum_total: int = 3 * maxi(0, requirement.sets_of_3 - int(progress.get("sets_done", 0))) \
			+ 4 * maxi(0, requirement.runs_of_4 - int(progress.get("runs4_done", 0))) \
			+ 7 * maxi(0, requirement.runs_of_7 - int(progress.get("runs7_done", 0)))
		var largest: int = mini(13, hand.size() - minimum_total + _minimum_group_size(requirement, progress))
		for size in range(largest, _minimum_group_size(requirement, progress) - 1, -1):
			sizes.append(size)
	else:
		if int(progress.get("runs7_done", 0)) < requirement.runs_of_7:
			sizes.append(7)
		if int(progress.get("runs4_done", 0)) < requirement.runs_of_4:
			sizes.append(4)
		if int(progress.get("sets_done", 0)) < requirement.sets_of_3:
			sizes.append(3)
	return sizes

static func _search_combinations(hand: Array, requirement: RoundRequirement, progress: Dictionary, budget: Dictionary, target_size: int, next_index: int, selected_indices: Array) -> Dictionary:
	if selected_indices.size() == target_size:
		budget["left"] = int(budget["left"]) - 1
		if int(budget["left"]) < 0:
			return {"ok": false}
		var selected: Array[Card] = []
		var selected_data: Array = []
		var remaining: Array = []
		for index in range(hand.size()):
			var card_data: Dictionary = hand[index]
			if selected_indices.has(index):
				selected.append(Card.from_dict(card_data))
				selected_data.append(card_data)
			else:
				remaining.append(card_data)
		var validation: Dictionary = PutDownValidator.validate_single_group(selected, requirement, progress)
		if not bool(validation.get("ok", false)):
			return {"ok": false}
		var continuation: Dictionary = _search(remaining, requirement, _advanced_progress(progress, validation), budget)
		if bool(continuation.get("ok", false)):
			var groups: Array = [selected_data]
			groups.append_array(continuation.get("groups", []))
			return {"ok": true, "groups": groups}
		return {"ok": false}
	for index in range(next_index, hand.size() - (target_size - selected_indices.size()) + 1):
		if int(budget["left"]) <= 0:
			break
		selected_indices.append(index)
		var found: Dictionary = _search_combinations(hand, requirement, progress, budget, target_size, index + 1, selected_indices)
		selected_indices.pop_back()
		if bool(found.get("ok", false)):
			return found
	return {"ok": false}

static func _advanced_progress(progress: Dictionary, validation: Dictionary) -> Dictionary:
	var next: Dictionary = progress.duplicate(true)
	match str(validation.get("group_type", "")):
		PutDownValidator.GROUP_SET_3:
			next["sets_done"] = int(next.get("sets_done", 0)) + 1
			var set_numbers: Array = next.get("set_numbers", [])
			set_numbers.append(int(validation.get("set_number", -1)))
			next["set_numbers"] = set_numbers
		PutDownValidator.GROUP_RUN_4:
			next["runs4_done"] = int(next.get("runs4_done", 0)) + 1
			var run_suits: Array = next.get("run_suits", [])
			run_suits.append(int(validation.get("run_suit", -1)))
			next["run_suits"] = run_suits
		PutDownValidator.GROUP_RUN_7:
			next["runs7_done"] = int(next.get("runs7_done", 0)) + 1
			var run_suits: Array = next.get("run_suits", [])
			run_suits.append(int(validation.get("run_suit", -1)))
			next["run_suits"] = run_suits
	return next

static func _remaining_slots(requirement: RoundRequirement, progress: Dictionary) -> int:
	return maxi(0, requirement.sets_of_3 - int(progress.get("sets_done", 0))) \
		+ maxi(0, requirement.runs_of_4 - int(progress.get("runs4_done", 0))) \
		+ maxi(0, requirement.runs_of_7 - int(progress.get("runs7_done", 0)))

static func _minimum_group_size(requirement: RoundRequirement, progress: Dictionary) -> int:
	var minimum: int = 99
	if int(progress.get("sets_done", 0)) < requirement.sets_of_3:
		minimum = mini(minimum, 3)
	if int(progress.get("runs4_done", 0)) < requirement.runs_of_4:
		minimum = mini(minimum, 4)
	if int(progress.get("runs7_done", 0)) < requirement.runs_of_7:
		minimum = mini(minimum, 7)
	return minimum
