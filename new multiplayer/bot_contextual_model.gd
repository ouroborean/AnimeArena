## Contextual bandits model for bot ability/target selection.
##
## Unlike the flat win-rate tracker (BotTrainingData), this model is STATE-AWARE.
## Each (character, ability) pair has a learned weight vector.  At decision time
## we extract features from the current board state (HP ratios, alive counts,
## energy, etc.) and score each option via dot(weights, features).
##
## After each match the weights are nudged via a REINFORCE-style update:
##   w += lr * reward * features
## where reward = +1 for a winning action and -1 for a losing one.
##
## Selection uses softmax over scores, which naturally explores when the model
## is unsure (weights near zero → uniform) and exploits as weights grow.

extends RefCounted
class_name BotContextualModel

const SAVE_PATH := "res://bot_contextual_model.json"

# ── Feature dimensions ──
const NUM_ABILITY_FEATURES := 17
const NUM_TARGET_FEATURES  := 13

# ── Hyper-parameters ──
const BASE_LEARNING_RATE := 0.05
const EPSILON := 0.10            ## Initial pure-random exploration rate
const SOFTMAX_TEMPERATURE := 1.0 ## Initial exploitation sharpness

# ── Exploration annealing ──
# Past EXPLORATION_DECAY_THRESHOLD updates on a (char, ability) entry, the
# model has converged enough that pure exploration is hurting more than
# helping. Linearly interpolate epsilon and softmax temperature toward the
# FINAL values so the bot exploits more often where it's confident, while
# still keeping a floor of randomness for low-data entries.
const EXPLORATION_DECAY_THRESHOLD := 500
const EPSILON_FINAL := 0.02
const TEMPERATURE_FINAL := 0.5

# Threshold above which an ability counts as a "burst" option for `burst_ready`.
const BURST_DAMAGE_THRESHOLD := 40.0

## Per-action diagnostic prints in _contextual_bot_act. Default off so live
## games don't spam the console. The harness sets it true explicitly when
## its own `verbose` export is on (and false otherwise) in its _ready, so
## changing this default doesn't affect harness behavior.
static var verbose_logging: bool = false

# ── Human-readable names for logging ──
# Indices 0-7 are the original macro-state features; 8+ are added later.
# Append-only — do not reorder, or saved weights will misalign.
const ABILITY_FEATURE_NAMES := [
	"user_hp", "ally_hp", "enemy_hp", "allies_alive",
	"enemies_alive", "energy", "low_enemy_hp", "bias",
	"max_enemy_threat", "burst_ready", "energy_per_member",
	"turn_norm", "hp_lead", "dead_enemies",
	# Per-ability features (depend on the candidate ability being scored)
	"cost_ratio", "color_starvation", "would_break_burst",
]
const TARGET_FEATURE_NAMES := [
	"target_hp", "is_enemy", "hp_diff", "effects",
	"user_hp", "allies_alive", "enemies_alive", "bias",
	"target_threat", "target_disabled", "target_lethal",
	"target_kit_dmg", "target_cd_load",
]

## Nested dictionary:
##   data[char_name][ability_name] = {
##     "ability_weights": Array[float],  (length NUM_ABILITY_FEATURES)
##     "target_weights":  Array[float],  (length NUM_TARGET_FEATURES)
##     "updates": int
##   }
var data: Dictionary = {}

## Per-match pending buffer — two sides recording independently.
## Each entry: [char_name, ability_name, target_name, ability_features, target_features]
var _pending: Array = [[], []]


# ===========================================================================
# FEATURE EXTRACTION
# ===========================================================================

## Features used to score which ABILITY to pick. Indices 0-13 are board-level
## (same vector regardless of which ability is being scored). Indices 14-16
## are per-ability — they depend on the specific candidate `ability` and let
## the model differentiate "use the cheap option" vs "use the expensive
## finisher" within the same board state. Pass `ability=null` for backward
## compatibility (per-ability features default to 0, neutral).
static func extract_ability_features(character, battle, ability = null) -> Array:
	var user_hp_ratio := float(character.health.hp) / maxf(float(character.health.max_hp), 1.0)

	var allies  := _get_alive_faction(character, battle, true)
	var enemies := _get_alive_faction(character, battle, false)

	var avg_ally_hp := 0.0
	for a in allies:
		avg_ally_hp += float(a.health.hp) / maxf(float(a.health.max_hp), 1.0)
	avg_ally_hp = avg_ally_hp / maxf(allies.size(), 1)

	var avg_enemy_hp := 0.0
	var low_enemy_hp := 1.0
	for e in enemies:
		var r := float(e.health.hp) / maxf(float(e.health.max_hp), 1.0)
		avg_enemy_hp += r
		if r < low_enemy_hp:
			low_enemy_hp = r
	avg_enemy_hp = avg_enemy_hp / maxf(enemies.size(), 1)

	var allies_alive_ratio  := float(allies.size())  / 3.0
	var enemies_alive_ratio := float(enemies.size()) / 3.0

	var energy_ratio := clampf(float(character.team.energy.total_available()) / 12.0, 0.0, 1.0)

	# ── Extended features (indices 8-13) ──
	var max_enemy_threat := _max_threat(enemies)
	var burst_ready := 1.0 if _has_burst_ready(character, BURST_DAMAGE_THRESHOLD) else 0.0
	var energy_per_member := clampf(
		float(character.team.energy.total_available()) / maxf(float(allies.size()) * 4.0, 1.0),
		0.0, 1.0)
	var turn_norm := clampf(float(battle.current_turn_number) / 20.0, 0.0, 1.0)
	var hp_lead := avg_ally_hp - avg_enemy_hp  # range [-1, 1]
	var dead_enemies := (3.0 - float(enemies.size())) / 3.0

	# ── Per-ability features (indices 14-16) ──
	# Default 0 when ability is null (backward-compat callers); otherwise
	# captures cost interactions that let the model learn "save energy when
	# this ability isn't the best use of it." See helper docstrings below.
	var cost_ratio = 0.0
	var color_starvation = 0.0
	var would_break_burst = 0.0
	if ability != null:
		cost_ratio = _ability_cost_ratio(ability, character.team)
		color_starvation = _ability_color_starvation(ability, character.team)
		would_break_burst = _ability_would_break_burst(ability, character)

	return [
		user_hp_ratio,
		avg_ally_hp,
		avg_enemy_hp,
		allies_alive_ratio,
		enemies_alive_ratio,
		energy_ratio,
		low_enemy_hp,
		1.0,  # bias
		max_enemy_threat,
		burst_ready,
		energy_per_member,
		turn_norm,
		hp_lead,
		dead_enemies,
		cost_ratio,
		color_starvation,
		would_break_burst,
	]


## Per-candidate features used to score which TARGET to pick.
## `ability` is the chosen ability — required for `target_lethal`. Defaults to
## null so older callers compile, but the lethal feature degrades to 0 then.
static func extract_target_features(character, target, battle, ability = null) -> Array:
	var user_hp_ratio   := float(character.health.hp) / maxf(float(character.health.max_hp), 1.0)
	var target_hp_ratio := float(target.health.hp)    / maxf(float(target.health.max_hp), 1.0)
	var is_enemy        := 1.0 if target.enemy != character.enemy else 0.0
	var hp_difference   := target_hp_ratio - user_hp_ratio

	var allies  := _get_alive_faction(character, battle, true)
	var enemies := _get_alive_faction(character, battle, false)

	var effect_count := float(target.effects._effects.size())
	var effect_norm  := clampf(effect_count / 10.0, 0.0, 1.0)

	# ── Extended features (indices 8-12) ──
	var target_threat := clampf(_max_off_cd_damage(target) / 100.0, 0.0, 1.0)
	var target_disabled := 1.0 if _is_disabled(target) else 0.0
	var target_lethal := 0.0
	if ability != null and float(ability.bot_damage_hint()) >= float(target.health.hp):
		target_lethal = 1.0
	var target_kit_dmg := _kit_damage_avg(target)
	var target_cd_load := _cooldown_load(target)

	return [
		target_hp_ratio,
		is_enemy,
		hp_difference,
		effect_norm,
		user_hp_ratio,
		float(allies.size())  / 3.0,
		float(enemies.size()) / 3.0,
		1.0,  # bias
		target_threat,
		target_disabled,
		target_lethal,
		target_kit_dmg,
		target_cd_load,
	]


## Helper — get alive characters on the same (same=true) or opposite side.
static func _get_alive_faction(character, battle, same: bool) -> Array:
	var result := []
	for c in battle.all_characters():
		if c.dead or c.banished:
			continue
		var same_side = (c.enemy == character.enemy)
		if same_side == same:
			result.append(c)
	return result


## Best off-cooldown single-target damage hint across a character's kit.
## Used for both team-wide threat aggregation and per-target threat scoring.
static func _max_off_cd_damage(character) -> float:
	var max_dmg := 0.0
	for ab in character.moveset.get_active_abilities(character):
		if ab.cooldown_remaining > 0:
			continue
		var d: float = float(ab.bot_damage_hint())
		if d > max_dmg:
			max_dmg = d
	return max_dmg


## Highest threat across a list of characters, normalized by 100 hp.
static func _max_threat(characters: Array) -> float:
	var max_dmg := 0.0
	for c in characters:
		var d := _max_off_cd_damage(c)
		if d > max_dmg:
			max_dmg = d
	return clampf(max_dmg / 100.0, 0.0, 1.0)


static func _has_burst_ready(character, threshold: float) -> bool:
	for ab in character.moveset.get_active_abilities(character):
		if ab.cooldown_remaining > 0:
			continue
		if float(ab.bot_damage_hint()) >= threshold:
			return true
	return false


## Average damage hint across this character's full kit (no cooldown filter).
## Proxy for kit role: high = damage dealer, low = support/utility.
static func _kit_damage_avg(character) -> float:
	var abilities = character.moveset.get_active_abilities(character)
	if abilities.is_empty():
		return 0.0
	var total := 0.0
	for ab in abilities:
		total += float(ab.bot_damage_hint())
	return clampf((total / float(abilities.size())) / 50.0, 0.0, 1.0)


## Fraction of a character's kit currently on cooldown — high = "spent".
static func _cooldown_load(character) -> float:
	var abilities = character.moveset.get_active_abilities(character)
	if abilities.is_empty():
		return 0.0
	var on_cd := 0
	for ab in abilities:
		if ab.cooldown_remaining > 0:
			on_cd += 1
	return float(on_cd) / float(abilities.size())


static func _is_disabled(character) -> bool:
	return character.has_stuns() or character.has_silences()


## Fraction of the team's currently-available energy this ability would
## consume. 0 = free, 1 = drains the whole pool. Lets the model learn
## "expensive abilities should only fire when they're the best use of
## scarce energy" — useful for cheap utility characters that would
## otherwise burn the team's color budget on low-impact pokes.
static func _ability_cost_ratio(ability, team) -> float:
	var cost = ability.cost()
	var total: float = 0.0
	for k in cost:
		total += float(cost[k])
	var available = float(team.energy.total_available())
	if available <= 0.0:
		return 1.0
	return clampf(total / available, 0.0, 1.0)


## Of the colors this ability needs (excluding RANDOM, which can be paid by
## any color), how thin is the most-stretched color after paying? Returns
## the max ratio of (cost_in_color / pool_in_color) across required colors.
## A value near 1.0 means using this ability would leave that color empty —
## a strong signal that the energy is better saved for a teammate who
## specifically needs that color.
static func _ability_color_starvation(ability, team) -> float:
	var cost = ability.cost()
	var max_ratio: float = 0.0
	for color in cost:
		if color == Energy.Type.RANDOM:
			continue
		var c = float(cost[color])
		if c <= 0.0:
			continue
		var avail = float(team.energy.pool[color])
		if avail <= 0.0:
			return 1.0
		var ratio = c / avail
		if ratio > max_ratio:
			max_ratio = ratio
	return clampf(max_ratio, 0.0, 1.0)


## Returns 1.0 if using this ability would put the character's BEST OTHER
## burst-tier ability out of reach (i.e. unaffordable next turn); else 0.0.
## Excludes the candidate ability itself from the comparison — using a burst
## isn't penalized for breaking itself. Returns 0.0 if the burst is already
## unaffordable now (this ability can't make worse what's already broken).
static func _ability_would_break_burst(ability, character) -> float:
	var best_burst = null
	var best_dmg: float = 0.0
	for ab in character.moveset.get_active_abilities(character):
		if ab == ability:
			continue
		var d = float(ab.bot_damage_hint())
		if d >= BURST_DAMAGE_THRESHOLD and d > best_dmg:
			best_burst = ab
			best_dmg = d
	if best_burst == null:
		return 0.0

	# Is the burst affordable RIGHT NOW (before paying for `ability`)?
	# If not, this ability can't make it worse than already-broken — neutral.
	var pool: Dictionary = character.team.energy.pool.duplicate()
	var burst_cost = best_burst.cost()
	for k in burst_cost:
		if k == Energy.Type.RANDOM:
			continue
		if int(pool.get(k, 0)) < int(burst_cost[k]):
			return 0.0

	# Simulate paying for `ability`, then re-check burst affordability.
	var ability_cost = ability.cost()
	for k in ability_cost:
		if k == Energy.Type.RANDOM:
			continue
		pool[k] = max(0, int(pool.get(k, 0)) - int(ability_cost[k]))
	for k in burst_cost:
		if k == Energy.Type.RANDOM:
			continue
		if int(pool.get(k, 0)) < int(burst_cost[k]):
			return 1.0
	return 0.0


# ===========================================================================
# SCORING
# ===========================================================================

## Score an ability in a given state.  Returns 0.0 if no data (neutral).
func get_ability_score(char_name: String, ability_name: String, features: Array) -> float:
	var entry = _get_entry(char_name, ability_name)
	if entry == null:
		return 0.0
	return _dot(entry.ability_weights, features)


## Score a target candidate in a given state.
func get_target_score(char_name: String, ability_name: String, features: Array) -> float:
	var entry = _get_entry(char_name, ability_name)
	if entry == null:
		return 0.0
	return _dot(entry.target_weights, features)


# ===========================================================================
# SELECTION — softmax with epsilon-greedy exploration
# ===========================================================================

## Pick an index from `scores` using softmax, with EPSILON chance of random.
## Constant exploration — used when no entry context is available.
static func pick(scores: Array) -> int:
	if scores.is_empty():
		return 0
	if randf() < EPSILON:
		return randi() % scores.size()
	return _softmax_sample(scores, SOFTMAX_TEMPERATURE)


## Pick an index from `scores` with annealed exploration based on how many
## REINFORCE updates the relevant entry has received. Higher `updates` →
## lower epsilon and tighter softmax temperature → more exploitation.
## At updates=0 behaves identically to pick(); at updates >= threshold
## reaches the FINAL exploration values.
static func pick_annealed(scores: Array, updates: int) -> int:
	if scores.is_empty():
		return 0
	var t = clampf(float(updates) / float(EXPLORATION_DECAY_THRESHOLD), 0.0, 1.0)
	var eps = lerpf(EPSILON, EPSILON_FINAL, t)
	var temp = lerpf(SOFTMAX_TEMPERATURE, TEMPERATURE_FINAL, t)
	if randf() < eps:
		return randi() % scores.size()
	return _softmax_sample(scores, temp)


## For ability selection: returns the smallest update count across the
## given ability entries on `char_name`. Using the minimum (rather than
## avg) keeps annealing conservative — the bot keeps exploring until even
## the least-trained candidate has matured. Returns 0 if no entries exist.
func get_min_updates_for_abilities(char_name: String, ability_names: Array) -> int:
	var min_u = -1
	for ab in ability_names:
		var entry = _get_entry(char_name, ab)
		if entry == null:
			continue
		var u = int(entry.get("updates", 0))
		if min_u < 0 or u < min_u:
			min_u = u
	return 0 if min_u < 0 else min_u


static func _softmax_sample(scores: Array, temperature: float) -> int:
	# Numerical stability: subtract max before exp
	var max_s = scores[0]
	for s in scores:
		if s > max_s:
			max_s = s
	var exp_scores := []
	var total := 0.0
	for s in scores:
		var e := exp((s - max_s) / maxf(temperature, 0.01))
		exp_scores.append(e)
		total += e
	var roll := randf() * total
	var cumulative := 0.0
	for i in range(exp_scores.size()):
		cumulative += exp_scores[i]
		if roll <= cumulative:
			return i
	return exp_scores.size() - 1


# ===========================================================================
# PER-MATCH RECORDING
# ===========================================================================

func record_action(side: int, char_name: String, ability_name: String,
		target_name: String, ability_features: Array, target_features: Array):
	_pending[side].append([char_name, ability_name, target_name,
		ability_features, target_features])


## Commits this match's pending actions with REINFORCE-style updates.
## `reward_magnitude` (default 1.0) scales the +1/-1 sign — pass a higher
## value for blowout wins/losses to amplify learning, a lower value for
## photo-finish matches to soften it. See test_battle_headless's
## _compute_hp_margin_reward for the typical mapping.
func commit_match(winning_side: int, reward_magnitude: float = 1.0):
	var losing_side := 1 - winning_side
	for action in _pending[winning_side]:
		_update_weights(action[0], action[1], action[3], action[4], reward_magnitude)
	for action in _pending[losing_side]:
		_update_weights(action[0], action[1], action[3], action[4], -reward_magnitude)
	_pending = [[], []]


func commit_draw():
	_pending = [[], []]


# ===========================================================================
# WEIGHT UPDATE  —  REINFORCE-style: w += lr * reward * features
# ===========================================================================

func _update_weights(char_name: String, ability_name: String,
		ability_features: Array, target_features: Array, reward: float):
	_ensure_entry(char_name, ability_name)
	var entry = data[char_name][ability_name]
	entry.updates += 1

	# Learning rate decays as this entry gets more updates
	var lr := BASE_LEARNING_RATE / (1.0 + float(entry.updates) / 200.0)

	for i in range(NUM_ABILITY_FEATURES):
		entry.ability_weights[i] += lr * reward * float(ability_features[i])
	for i in range(NUM_TARGET_FEATURES):
		entry.target_weights[i] += lr * reward * float(target_features[i])


# ===========================================================================
# PERSISTENCE
# ===========================================================================

static func load_from_disk() -> BotContextualModel:
	return load_from_path(SAVE_PATH)


## Load a model from an arbitrary path. Used by eval mode in the headless
## harness to compare two saved models without overwriting either.
static func load_from_path(path: String) -> BotContextualModel:
	var model := BotContextualModel.new()
	if not FileAccess.file_exists(path):
		print("[ctx-model] No existing model at %s — starting fresh" % path)
		return model
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("BotContextualModel: could not open %s" % path)
		return model
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		model.data = json.data
		var padded := model._migrate_feature_dimensions()
		print("[ctx-model] Loaded %s: %d characters, %d ability models (padded %d entries)" % [
			path, model.data.size(), model._total_entries(), padded])
	else:
		push_warning("BotContextualModel: failed to parse %s" % path)
	file.close()
	return model


## Pads weight vectors to current feature dimensions. Old entries saved with
## smaller feature counts get zero-padded so they behave identically until the
## new features start receiving updates. Returns count of entries padded.
func _migrate_feature_dimensions() -> int:
	var padded := 0
	for char_name in data:
		for ab_name in data[char_name]:
			var entry = data[char_name][ab_name]
			var aw = entry.get("ability_weights", [])
			var tw = entry.get("target_weights", [])
			var was_padded := false
			while aw.size() < NUM_ABILITY_FEATURES:
				aw.append(0.0)
				was_padded = true
			while tw.size() < NUM_TARGET_FEATURES:
				tw.append(0.0)
				was_padded = true
			entry["ability_weights"] = aw
			entry["target_weights"] = tw
			if was_padded:
				padded += 1
	return padded


func save_to_disk():
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("BotContextualModel: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[ctx-model] Saved model: %d characters, %d ability models -> %s" % [
		data.size(), _total_entries(), SAVE_PATH])


# ===========================================================================
# DIAGNOSTICS
# ===========================================================================

func total_updates() -> int:
	var total := 0
	for char_name in data:
		for ab_name in data[char_name]:
			total += int(data[char_name][ab_name].get("updates", 0))
	return total


func get_entry_updates(char_name: String, ability_name: String) -> int:
	var entry = _get_entry(char_name, ability_name)
	if entry == null:
		return 0
	return int(entry.get("updates", 0))


# ===========================================================================
# INTERNALS
# ===========================================================================

func _get_entry(char_name: String, ability_name: String):
	if char_name not in data:
		return null
	if ability_name not in data[char_name]:
		return null
	return data[char_name][ability_name]


func _ensure_entry(char_name: String, ability_name: String):
	if char_name not in data:
		data[char_name] = {}
	if ability_name not in data[char_name]:
		data[char_name][ability_name] = {
			"ability_weights": _zero_array(NUM_ABILITY_FEATURES),
			"target_weights":  _zero_array(NUM_TARGET_FEATURES),
			"updates": 0,
		}


static func _zero_array(n: int) -> Array:
	var a := []
	for i in range(n):
		a.append(0.0)
	return a


static func _dot(a: Array, b: Array) -> float:
	var result := 0.0
	var n := mini(a.size(), b.size())
	for i in range(n):
		result += float(a[i]) * float(b[i])
	return result


func _total_entries() -> int:
	var total := 0
	for char_name in data:
		total += data[char_name].size()
	return total
