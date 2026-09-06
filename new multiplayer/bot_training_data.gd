## Persistent training data for bot ability/target selection.
##
## Tracks win rates for (character, ability) and (character, ability, target)
## combinations across matches.  Uses Laplace-smoothed scores so new actions
## start at 0.5 and converge toward their true win rate as data accumulates.
##
## Data is saved as JSON to user://bot_training_data.json and persists
## across Godot sessions.

extends RefCounted
class_name BotTrainingData

const SAVE_PATH := "res://bot_training_data.json"

## Nested dictionary:
##   data[char_name][ability_name] = {
##     "uses": int,
##     "wins": int,
##     "vs": {
##       target_name: { "uses": int, "wins": int }
##     }
##   }
var data: Dictionary = {}

## Per-match action buffers — two sides recording independently.
## Each entry is [char_name, ability_name, target_name].
var _pending: Array = [[], []]


# ===========================================================================
# LOAD / SAVE
# ===========================================================================

static func load_from_disk() -> BotTrainingData:
	var td := BotTrainingData.new()
	if not FileAccess.file_exists(SAVE_PATH):
		print("[train-data] No existing training data found — starting fresh")
		return td
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("BotTrainingData: could not open %s" % SAVE_PATH)
		return td
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		td.data = json.data
		print("[train-data] Loaded training data: %d characters, %d total action records" % [
			td.data.size(), td.total_actions()])
	else:
		push_warning("BotTrainingData: failed to parse %s" % SAVE_PATH)
	file.close()
	return td


func save_to_disk():
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("BotTrainingData: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[train-data] Saved training data: %d characters, %d action records -> %s" % [
		data.size(), total_actions(), SAVE_PATH])


# ===========================================================================
# PER-MATCH RECORDING
# ===========================================================================

## Record an action taken by one side during a match.
## side: 0 = player team, 1 = enemy team.
func record_action(side: int, char_name: String, ability_name: String, target_name: String):
	_pending[side].append([char_name, ability_name, target_name])


## After a match ends, attribute wins/losses to all recorded actions.
## winning_side: 0 if side-0 won, 1 if side-1 won.
func commit_match(winning_side: int):
	var losing_side := 1 - winning_side
	for action in _pending[winning_side]:
		_update_entry(action[0], action[1], action[2], true)
	for action in _pending[losing_side]:
		_update_entry(action[0], action[1], action[2], false)
	_pending = [[], []]


## Draws don't count toward win/loss data — just clear the buffer.
func commit_draw():
	_pending = [[], []]


# ===========================================================================
# SCORING  —  Laplace-smoothed win rate:  (wins + 1) / (uses + 2)
#              New entries start at 0.5 and converge toward the true rate.
# ===========================================================================

## Score for choosing this ability on this character (any target).
func get_ability_score(char_name: String, ability_name: String) -> float:
	var s = _get_ability_entry(char_name, ability_name)
	if s == null:
		return 0.5
	return (float(s.wins) + 1.0) / (float(s.uses) + 2.0)


## Score for targeting a specific character with this ability.
func get_target_score(char_name: String, ability_name: String, target_name: String) -> float:
	var s = _get_target_entry(char_name, ability_name, target_name)
	if s == null:
		return 0.5
	return (float(s.wins) + 1.0) / (float(s.uses) + 2.0)


## Return ability-level stats { uses, wins } or null if no data.
func get_ability_stats(char_name: String, ability_name: String):
	return _get_ability_entry(char_name, ability_name)


## Return target-level stats { uses, wins } or null if no data.
func get_target_stats(char_name: String, ability_name: String, target_name: String):
	return _get_target_entry(char_name, ability_name, target_name)


## Sum of all recorded uses across every character/ability.
func total_actions() -> int:
	var total := 0
	for char_name in data:
		for ability_name in data[char_name]:
			total += int(data[char_name][ability_name].get("uses", 0))
	return total


# ===========================================================================
# INTERNALS
# ===========================================================================

func _get_ability_entry(char_name: String, ability_name: String):
	if char_name not in data:
		return null
	if ability_name not in data[char_name]:
		return null
	return data[char_name][ability_name]


func _get_target_entry(char_name: String, ability_name: String, target_name: String):
	var ability_entry = _get_ability_entry(char_name, ability_name)
	if ability_entry == null:
		return null
	if "vs" not in ability_entry:
		return null
	if target_name not in ability_entry.vs:
		return null
	return ability_entry.vs[target_name]


func _update_entry(char_name: String, ability_name: String, target_name: String, won: bool):
	# Ensure nested structure exists
	if char_name not in data:
		data[char_name] = {}
	if ability_name not in data[char_name]:
		data[char_name][ability_name] = { "uses": 0, "wins": 0, "vs": {} }

	var entry = data[char_name][ability_name]
	entry.uses += 1
	if won:
		entry.wins += 1

	if target_name not in entry.vs:
		entry.vs[target_name] = { "uses": 0, "wins": 0 }
	entry.vs[target_name].uses += 1
	if won:
		entry.vs[target_name].wins += 1
