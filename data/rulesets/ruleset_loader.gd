extends RefCounted
class_name RulesetLoader

var last_error: String = "" # Stores the most recent load/build error message.

func load_ruleset(path: String) -> Ruleset:
	# Reset any previous error before starting a new load.
	last_error = ""
	# Validate the file exists before trying to open it.
	if not FileAccess.file_exists(path):
		last_error = "Ruleset file not found: %s" % path
		return null
	# Open the file for reading.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Failed to open ruleset file: %s" % path
		return null
	# Read the full file and parse JSON.
	var text := file.get_as_text()
	var data = JSON.parse_string(text)
	# Expect a JSON dictionary at the top level.
	if data == null or typeof(data) != TYPE_DICTIONARY:
		last_error = "Invalid JSON in ruleset file: %s" % path
		return null
	# Convert the dictionary into a Ruleset resource.
	return _build_ruleset_from_dict(data)

func _build_ruleset_from_dict(data: Dictionary) -> Ruleset:
	# Create the Ruleset instance and fill in metadata.
	var ruleset := Ruleset.new()
	ruleset.id = data.get("id", "default_ruleset")
	ruleset.name = data.get("name", "Default Ruleset")
	ruleset.description = data.get("description", "A standard ruleset for hot rum.")
	ruleset.max_rounds = int(data.get("rounds_total", 0))
	# Start with a clean requirements list.
	ruleset.round_requirements.clear()

	# Pull the per-round requirements list from the JSON.
	var rounds = data.get("rounds", [])
	if typeof(rounds) != TYPE_ARRAY:
		last_error = "Ruleset JSON missing 'rounds' array."
		return null

	# Build RoundRequirement entries from each array element.
	for round_data in rounds:
		# Skip any non-dictionary entries to avoid crashes.
		if typeof(round_data) != TYPE_DICTIONARY:
			continue
		var req := RoundRequirement.new()
		# Map JSON fields onto the requirement object.
		req.game_round = int(round_data.get("round", 0))
		req.deal_count = int(round_data.get("deal_count", 0))
		req.sets_of_3 = int(round_data.get("sets", 0))
		req.runs_of_4 = int(round_data.get("run_of_4", 0))
		req.runs_of_7 = int(round_data.get("run_of_7", 0))
		req.all_cards = bool(round_data.get("all_cards", false))
		# Add to the ruleset's list in the order read.
		ruleset.round_requirements.append(req)

	# Return the fully populated ruleset.
	return ruleset
