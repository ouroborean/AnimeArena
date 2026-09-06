# Color-balanced bot drafting — shared by char_select_scene (live game bot
# teams) and test_battle_headless (training/eval harness).
#
# Drafting algorithm:
#   1. First slot is uniform random over the eligible pool.
#   2. After slot 1, score each candidate:
#        - No-color characters (e.g. Crona): inherent value 50.
#        - Otherwise: +100 once if the candidate has AT LEAST ONE color
#          not yet on the team (single flat bonus regardless of how many
#          new colors they bring).
#        - Then -50 for EACH color the candidate has that's already on
#          the team.
#      The single-bonus design is deliberate: it stops the picker from
#      undervaluing 1-color characters relative to 3- or 4-color ones,
#      which previously made nearly every team contain a multi-color
#      character.
#   3. Pick uniformly at random among the highest-scoring candidates.
#
# Color encoding (Energy.Type): 0=GREEN 1=BLUE 2=WHITE 3=RED. RANDOM (4)
# is intentionally absent — characters whose costs are entirely random
# carry an empty array `[]` and use the inherent 50 above.

class_name ColorBalancedDraft
extends Object

const _COLOR_DATA_PATH = "res://character_colors.json"

# Score components — tuneable.
const _NEW_COLOR_BONUS = 100        # awarded ONCE if any color is new
const _OVERLAP_PENALTY = 50         # subtracted PER already-on-team color
const _EMPTY_KIT_VALUE = 50         # inherent value when candidate has no colors

static var _data: Dictionary = {}
static var _loaded = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f = FileAccess.open(_COLOR_DATA_PATH, FileAccess.READ)
	if f == null:
		push_warning("character_colors.json not found at %s — drafts will fall back to random" % _COLOR_DATA_PATH)
		return
	var json = JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	else:
		push_warning("Failed to parse %s — drafts will fall back to random" % _COLOR_DATA_PATH)
	f.close()


## Energy colors for a character path_name. Returns [] if unknown — treated
## as "no color identity" by the picker (same as Crona's drafting profile).
static func get_character_colors(name: String) -> Array:
	_ensure_loaded()
	if name in _data:
		return _data[name]
	return []


## Score a candidate against the current team's color set.
## See module-level docstring for the rule details.
## `team_color_set` is a Dictionary used as a set: keys are color ints
## already present on the team.
static func score_candidate(candidate_colors: Array, team_color_set: Dictionary) -> int:
	if candidate_colors.is_empty():
		return _EMPTY_KIT_VALUE

	var has_new_color := false
	var overlap_count := 0
	for c in candidate_colors:
		if team_color_set.has(c):
			overlap_count += 1
		else:
			has_new_color = true

	var score := 0
	if has_new_color:
		score += _NEW_COLOR_BONUS
	score -= _OVERLAP_PENALTY * overlap_count
	return score


## Pick the next team member to maximize color balance. `current_team` is
## the path_names already drafted. `pool` is the candidate pool. `excluded`
## skips characters that should never be picked (banned/locked). Empty
## `current_team` triggers a uniform-random first pick.
## `rng`: optional seeded RandomNumberGenerator — when provided, all random picks
## draw from it (reproducible training runs); when null, global RNG as before.
## Returns the picked path_name, or "" if no eligible candidates remain.
static func pick_next(current_team: Array, pool: Array, excluded: Array = [],
		rng: RandomNumberGenerator = null) -> String:
	if current_team.is_empty():
		var eligible: Array = []
		for name in pool:
			if name in excluded:
				continue
			eligible.append(name)
		if eligible.is_empty():
			return ""
		return _pick(eligible, rng)

	# Build the team's color set once (used by every candidate's score).
	var team_color_set: Dictionary = {}
	for name in current_team:
		for c in get_character_colors(name):
			team_color_set[c] = true

	var best_score = null
	var best_candidates: Array = []
	for name in pool:
		if name in current_team:
			continue
		if name in excluded:
			continue
		var colors = get_character_colors(name)
		var score = score_candidate(colors, team_color_set)
		if best_score == null or score > best_score:
			best_score = score
			best_candidates = [name]
		elif score == best_score:
			best_candidates.append(name)

	if best_candidates.is_empty():
		return ""
	return _pick(best_candidates, rng)


## Uniform pick from `arr`, using the caller's seeded rng when given.
static func _pick(arr: Array, rng: RandomNumberGenerator):
	if rng != null:
		return arr[rng.randi_range(0, arr.size() - 1)]
	return arr.pick_random()


## Build a complete team. `force` characters are seeded into the team first;
## the rest are filled by repeated pick_next() calls. Returns the full team
## (length up to `team_size`, fewer if the pool is exhausted before then).
static func build_team(pool: Array, team_size: int = 3, force: Array = [],
		excluded: Array = [], rng: RandomNumberGenerator = null) -> Array:
	var team: Array = force.duplicate()
	while team.size() < team_size:
		var pick = pick_next(team, pool, excluded, rng)
		if pick == "":
			break
		team.append(pick)
	return team
