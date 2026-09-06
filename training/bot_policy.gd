extends RefCounted
class_name BotPolicyV3

# ============================================================================
# v3 bot policy (see .claude/plans/bot-training-v3.md §2-3).
#
# Per-(character, ability) LINEAR scorers over a NAMED feature schema:
#   score(action) = dot(w, ability_features) + dot(tw, target_features)
# All state reads go through BotObservation (human-parity — the policy cannot
# see hidden information even by accident). Selection is softmax-with-
# temperature over the whole team's affordable candidates (T=0 → argmax), so
# one knob covers training exploration AND live difficulty tiers.
#
# Learning is trainer-driven: the trainer computes a discounted shaped return
# G per recorded action (reward shaping may read full state — only the
# POLICY's inputs must be parity-filtered; the outcome signal is just the
# score of the game) and calls apply_returns(). The policy owns the
# advantage baseline (per-character EMA), the lr schedule, and persistence.
#
# Persistence (bot_policy.json / checkpoints): weights are NAME-KEYED per
# feature in the file, so the schema can grow or reorder without corrupting
# saved weights (v2's positional arrays could not). Loaded into packed arrays
# once for inference speed.
#
# The tuning overlay (bot_tuning.json, spec §7) is applied at score time in
# tuned_score() and is NEVER touched by training — hand-adjust behavior
# without retraining.
# ============================================================================

const FORMAT := "aa-bot-policy"
const VERSION := 1

const FEATURE_SCHEMA: Array[String] = [
	"bias",
	"my_hp_ratio",              # acting character's hp ratio
	"team_hp_ratio",            # own team avg hp ratio (dead = 0)
	"allies_alive_frac",
	"enemies_alive_frac",
	"avg_enemy_hp_ratio",       # over living enemies
	"min_enemy_hp_ratio",       # kill-target proximity
	"turn_progress",            # turn/30 capped 1
	"pool_total_norm",          # own energy total /8 capped 1
	"energy_after_cost_norm",   # (total - cost)/8 clamped 0..1
	"cost_total_norm",          # cost/4 capped 1
	"is_free",
	"dmg_hint_norm",            # static damage hint /50 capped 1.5
	"kill_available",           # hint >= min living enemy hp
	"my_visible_debuffs_norm",  # visible debuffs on the actor /3 capped 1
	"enemy_pressure_norm",      # my team's visible effects on living enemies /6 capped 1
	"acted_allies_frac",        # how late in my turn this pick is
	# --- APPENDED (semantic layer). Indices 0-16 above MUST NOT MOVE: weights are
	# name-keyed on disk, so appending loads existing checkpoints with these at 0.0.
	#
	# Everything here VARIES BETWEEN CANDIDATE ABILITIES. That is the whole point:
	# the shared gradient is phi - E_pi[phi], so a feature constant across the
	# candidate set has exactly zero gradient forever. Ten of the sixteen features
	# above are dead for precisely that reason (measured at machine epsilon after
	# 548k updates), which left the shared layer ranking abilities on ~4 effective
	# DOF: cost, damage hint, and two actor properties.
	"cd_norm",                  # base cooldown /4 capped 1 - the game's own "this is a finisher"
	"t_damage_now",             # Damaging class: works for the ~70% of abilities whose damage hint is 0
	"t_control",                # applies stun/silence/paralyze/taunt/blind/isolate/banish
	"t_invuln",                 # grants invulnerability / immortality
	"t_mitigate",               # shield / barrier / damage reduction / damage cap
	"t_heal",                   # heals
	"t_mark",                   # applies a mark (the setup half of most combos)
	"t_reactive",               # counter / reflect / redirect / trigger
	"t_amplify",                # damage mod / vulnerability / defense negate
	"aoe_fanout_norm",          # (targets-1)/2 capped 1 for team-wide skills
	# The two below RESURRECT dead globals: team_hp_ratio and my_hp_ratio have exactly
	# zero gradient on their own (constant across candidates), but multiplied by an
	# ability semantic the product varies, so "heal when the team is hurt" and "guard
	# when I am hurt" become learnable for the first time.
	"heal_x_team_missing",      # t_heal * (1 - team_hp_ratio)
	"guard_x_self_hurt",        # (t_mitigate or t_invuln) * (1 - my_hp_ratio)
]

const TARGET_SCHEMA: Array[String] = [
	"bias",
	"is_ally",
	"is_self",
	"hp_ratio",
	"missing_ratio",
	"missing_hp_norm",          # (max-hp)/100 — heal sizing
	"kill_in_range",            # hostile: hint >= target hp
	"is_stunned_visible",       # visible STUN effect on target
	"debuff_count_norm",        # visible hostile-cast effects /3 capped 1
	"buff_count_norm",
	"marked_by_me",             # I have a visible effect on them
	"threat_norm",              # target's best static damage hint /50 (hostile only)
	"focus_fire",               # already targeted by an action planned this turn
	# --- APPENDED. Indices 0-12 above MUST NOT MOVE (name-keyed persistence).
	# These are ability x target-state INTERACTIONS, so they vary per candidate.
	"control_redundant",        # t_control into an already-disabled target = wasted
	"payload_denied",           # this payload cannot land (heal into ignore-healing, etc.)
	"reactive_on_target",       # target has a visible counter/reflect/trigger armed
	"target_shielded_norm",     # (shield + flat DR) / max_hp, zeroed when defense is broken
	"stacks_on_target_norm",    # deepest visible stack count /5 - stacking payoff windows
]

var generation := 0
var trained_matches := 0
# path -> ability_name -> {w: PackedFloat64Array, tw: PackedFloat64Array, updates: float}
var entries: Dictionary = {}
# Two-level advantage baseline: a fast GLOBAL return EMA (updated every
# record, so it converges within a few matches) plus a per-character EMA of
# the residual. A per-character-only baseline lags badly on a 170-char roster
# (most characters see a handful of records), leaving E[advantage] > 0 and
# inflating weights.
var global_baseline := 0.0
var global_baseline_beta := 0.02
# path -> float — per-character EMA of (G - global_baseline)
var baselines: Dictionary = {}
# SHARED layer: score = dot(shared, φ) + dot(per_ability, φ). The shared
# vector learns game-generic value ("kill_in_range good", "heal the hurt")
# from EVERY action across the whole roster, so lessons transfer; per-ability
# weights learn only the residual specialization. Without this, a 170-char
# roster needs thousands of matches before argmax beats noise (measured:
# 150 matches of per-ability-only learning evaluated at exactly 50% vs random).
var shared_w := PackedFloat64Array()
var shared_tw := PackedFloat64Array()
var shared_updates := 0.0

# Learning-rate schedule + baseline EMA factor (spec §3). The shared layer
# sees roughly two orders of magnitude more updates than any single entry,
# so its schedule anneals on a much longer horizon.
# "char|ability" -> PackedFloat64Array offset added to that entry's weights for the
# CURRENT MATCH ONLY. Deliberately kept OUT of `entries` so it can never be
# serialised: to_dict()/merge() only ever see the true weights, so a checkpoint can
# never accidentally bake in exploration noise.
var explore_offsets: Dictionary = {}

var lr0 := 0.05
var lr_tau := 400.0
var shared_lr_tau := 20000.0
var baseline_beta := 0.05


func _init():
	shared_w.resize(FEATURE_SCHEMA.size())
	shared_tw.resize(TARGET_SCHEMA.size())


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

func _entry(char_path: String, ability_name: String) -> Dictionary:
	if not entries.has(char_path):
		entries[char_path] = {}
	var char_entries: Dictionary = entries[char_path]
	if not char_entries.has(ability_name):
		var w := PackedFloat64Array()
		w.resize(FEATURE_SCHEMA.size())
		var tw := PackedFloat64Array()
		tw.resize(TARGET_SCHEMA.size())
		char_entries[ability_name] = {"w": w, "tw": tw, "updates": 0.0}
	return char_entries[ability_name]


static func _dot(weights: PackedFloat64Array, feats: PackedFloat64Array) -> float:
	var total := 0.0
	for i in range(mini(weights.size(), feats.size())):
		total += weights[i] * feats[i]
	return total


# --- semantic ability tags -------------------------------------------------
# Bit values must match training/bake_bot_tags.py. The table is keyed by ability
# NAME (ability_name), loaded once per process. A missing entry reads 0, which is
# safe: the ability simply contributes nothing to the semantic features, exactly
# as it did before this layer existed.
const TAG_CONTROL := 1
const TAG_INVULN := 2
const TAG_MITIGATE := 4
const TAG_HEAL := 8
const TAG_MARK := 16
const TAG_REACTIVE := 32
const TAG_AMPLIFY := 64

# File-level const, NOT EffectType.use_or_receive_triggers(): that is a static func
# that allocates a fresh Array on every call, and this is read once per
# (candidate, target) - roughly 36 allocations per decision on a live server.
const REACTIVE_TYPES: Array[int] = [
	EffectType.Type.ACTION_USE_TRIGGER, EffectType.Type.ACTION_RECEIVE_TRIGGER,
	EffectType.Type.HARMFUL_RECEIVE_TRIGGER, EffectType.Type.HARMFUL_USE_TRIGGER,
	EffectType.Type.HELPFUL_RECEIVE_TRIGGER, EffectType.Type.HELPFUL_USE_TRIGGER,
	EffectType.Type.DAMAGE_RECEIVE_TRIGGER, EffectType.Type.ON_DEATH_TRIGGER,
	EffectType.Type.HEALTH_CHANGE_TRIGGER, EffectType.Type.STUN_RECEIVED_TRIGGER,
	EffectType.Type.COUNTER_USE, EffectType.Type.COUNTER_RECEIVE,
	EffectType.Type.REFLECT_RECEIVE, EffectType.Type.REFLECT_USE,
]

static var _bot_tags: Dictionary = {}
static var _bot_tags_loaded := false

static func _tags_for(ability) -> int:
	if not _bot_tags_loaded:
		_bot_tags_loaded = true
		var path := "res://training/bot_tags.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and parsed.get("tags", null) is Dictionary:
				_bot_tags = parsed["tags"]
		if _bot_tags.is_empty():
			push_warning("[policy] bot_tags.json missing/empty - every semantic feature will be 0. Run training/bake_bot_tags.py")
	if ability == null:
		return 0
	# ScriptedAbility (player-authored) carries its own derived tags; shipped
	# abilities look up the baked table by source key.
	if "bot_tags" in ability and int(ability.bot_tags) != 0:
		return int(ability.bot_tags)
	var key := str(ability.get_script().resource_path.get_file().get_basename()) if ability.get_script() != null else ""
	return int(_bot_tags.get(key, 0))


func extract_ability_features(obs: BotObservation, character, cand: Dictionary) -> PackedFloat64Array:
	var f := PackedFloat64Array()
	f.resize(FEATURE_SCHEMA.size())
	var own = obs.own_characters()
	var enemies = obs.enemy_characters()
	var living_enemies = obs.living(enemies)
	var living_own = obs.living(own)

	var team_hp := 0.0
	var acted := 0
	for c in own:
		team_hp += obs.hp_ratio(c) if obs.is_alive(c) else 0.0
		if c.bot_acted or c.acted:
			acted += 1
	var avg_enemy_hp := 0.0
	var min_enemy_hp_ratio := 1.0
	var min_enemy_hp := 100
	for e in living_enemies:
		avg_enemy_hp += obs.hp_ratio(e)
		min_enemy_hp_ratio = minf(min_enemy_hp_ratio, obs.hp_ratio(e))
		min_enemy_hp = mini(min_enemy_hp, obs.hp(e))
	if living_enemies.size() > 0:
		avg_enemy_hp /= living_enemies.size()

	var cost: Dictionary = cand["cost"]
	var cost_total := 0
	for v in cost.values():
		cost_total += int(v)
	var pool_total := obs.own_energy_total()
	var hint := int(cand["ability"].bot_damage_hint())

	var pressure := 0
	for e in living_enemies:
		pressure += obs.visible_effects_from_viewer(e).size()

	f[0] = 1.0
	f[1] = obs.hp_ratio(character)
	f[2] = team_hp / 3.0
	f[3] = living_own.size() / 3.0
	f[4] = living_enemies.size() / 3.0
	f[5] = avg_enemy_hp
	f[6] = min_enemy_hp_ratio if living_enemies.size() > 0 else 0.0
	f[7] = obs.turn_progress()
	f[8] = minf(pool_total / 8.0, 1.0)
	f[9] = clampf((pool_total - cost_total) / 8.0, 0.0, 1.0)
	f[10] = minf(cost_total / 4.0, 1.0)
	f[11] = 1.0 if cost_total == 0 else 0.0
	f[12] = minf(hint / 50.0, 1.5)
	f[13] = 1.0 if (living_enemies.size() > 0 and hint > 0 and hint >= min_enemy_hp) else 0.0
	f[14] = minf(obs.visible_debuffs(character).size() / 3.0, 1.0)
	f[15] = minf(pressure / 6.0, 1.0)
	f[16] = acted / 3.0

	# --- semantic layer -----------------------------------------------------
	var abil = cand["ability"]
	var tags := _tags_for(abil)
	var t_heal := 1.0 if (tags & TAG_HEAL) else 0.0
	var t_mitigate := 1.0 if (tags & TAG_MITIGATE) else 0.0
	var t_invuln := 1.0 if (tags & TAG_INVULN) else 0.0
	# Compare target_type by CONSTANT, never by indexing the enum's values(): five
	# entries (nobara3/4, yuji2/3/4) carry an out-of-range target_type of 5.
	var ttype = cand.get("target_type", TargetType.Type.SINGLE)
	var n_targets: int = (cand["targets"] as Array).size() if cand.get("targets", null) is Array else 1
	var is_aoe: bool = (ttype == TargetType.Type.ALL or ttype == TargetType.Type.ALL_FACTION)

	f[17] = minf(float(int(abil.cooldown)) / 4.0, 1.0)
	f[18] = 1.0 if abil.classes.get("Damaging", false) else 0.0
	f[19] = 1.0 if (tags & TAG_CONTROL) else 0.0
	f[20] = t_invuln
	f[21] = t_mitigate
	f[22] = t_heal
	f[23] = 1.0 if (tags & TAG_MARK) else 0.0
	f[24] = 1.0 if (tags & TAG_REACTIVE) else 0.0
	f[25] = 1.0 if (tags & TAG_AMPLIFY) else 0.0
	f[26] = minf(float(maxi(n_targets - 1, 0)) / 2.0, 1.0) if is_aoe else 0.0
	f[27] = t_heal * (1.0 - (team_hp / 3.0))
	f[28] = maxf(t_mitigate, t_invuln) * (1.0 - obs.hp_ratio(character))
	return f


func extract_target_features(obs: BotObservation, character, cand: Dictionary,
		target, focus_map: Dictionary) -> PackedFloat64Array:
	var f := PackedFloat64Array()
	f.resize(TARGET_SCHEMA.size())
	var ally: bool = target.team == character.team
	var hint := int(cand["ability"].bot_damage_hint())
	var stunned := false
	var debuffs := 0
	var buffs := 0
	# Accumulated in the SAME pass - no extra walk over the effect list.
	var shield := 0
	var flat_dr := 0
	var shattered := false
	var disabled := false
	var heal_denied := false
	var nondmg_immune := false
	var reactive_armed := false
	var deepest_stack := 1
	for effect in obs.visible_effects(target):
		var et = effect.effect_type
		if et == EffectType.Type.STUN:
			stunned = true
		# mag is TYPE-OVERLOADED across effect kinds (Array on koro1, String on
		# megumi5, Vector2 on ABILITY_SWAP...). int(mag) on a non-int crashes a
		# live match - the wire serializer needed the same guard.
		var mag_i: int = int(effect.mag) if typeof(effect.mag) == TYPE_INT else 0
		match et:
			EffectType.Type.SHIELD: shield += mag_i
			EffectType.Type.DAMAGE_REDUCTION: flat_dr += mag_i
			EffectType.Type.DEF_NEGATE: shattered = true
			EffectType.Type.STUN, EffectType.Type.COST_STUN, EffectType.Type.FALSE_STUN, \
			EffectType.Type.PARALYZE, EffectType.Type.SILENCE, EffectType.Type.TAUNT, \
			EffectType.Type.BLIND, EffectType.Type.ISOLATE:
				disabled = true
			EffectType.Type.IGNORE_NON_DAMAGE: nondmg_immune = true
		if et == EffectType.Type.ISOLATE or et == EffectType.Type.IGNORE_HEALING or et == EffectType.Type.HEAL_CUT:
			heal_denied = true
		if et in REACTIVE_TYPES:
			reactive_armed = true
		# stack_count() can legitimately return -1 (reflect's "unlimited" sentinel).
		var sc = effect.stack_count()
		if typeof(sc) == TYPE_INT or typeof(sc) == TYPE_FLOAT:
			deepest_stack = maxi(deepest_stack, int(sc))
		var caster = effect.user
		if caster != null and is_instance_valid(caster) and caster.team != target.team:
			debuffs += 1
		else:
			buffs += 1
	# Breaking defense zeroes both flat DR and invulnerability in the engine, so a
	# shattered target must not read as protected.
	if shattered:
		flat_dr = 0

	f[0] = 1.0
	f[1] = 1.0 if ally else 0.0
	f[2] = 1.0 if target == character else 0.0
	f[3] = obs.hp_ratio(target)
	f[4] = 1.0 - obs.hp_ratio(target)
	f[5] = clampf((obs.max_hp(target) - obs.hp(target)) / 100.0, 0.0, 1.0)
	f[6] = 1.0 if (not ally and hint > 0 and hint >= obs.hp(target)) else 0.0
	f[7] = 1.0 if stunned else 0.0
	f[8] = minf(debuffs / 3.0, 1.0)
	f[9] = minf(buffs / 3.0, 1.0)
	f[10] = 1.0 if obs.visible_effects_from_viewer(target).size() > 0 else 0.0
	f[11] = 0.0 if ally else minf(obs.enemy_threat(target) / 50.0, 1.5)
	f[12] = 1.0 if focus_map.has(target) else 0.0

	# --- semantic interactions ----------------------------------------------
	var tags := _tags_for(cand["ability"])
	var damaging: bool = cand["ability"].classes.get("Damaging", false)
	# maxi(1, ...) - a dead/banished character can report max_hp 0, and 0.0 * INF
	# is NaN, which loses every comparison and would silently change the argmax.
	var mhp := maxi(1, obs.max_hp(target))
	f[13] = 1.0 if ((tags & TAG_CONTROL) and disabled) else 0.0
	f[14] = 1.0 if (((tags & TAG_HEAL) and heal_denied) \
		or (nondmg_immune and not damaging and not ally)) else 0.0
	f[15] = 1.0 if reactive_armed else 0.0
	f[16] = clampf(float(shield + flat_dr) / float(mhp), 0.0, 1.0)
	f[17] = minf(float(maxi(deepest_stack, 1)) / 5.0, 1.0)
	return f


# --- live combat heuristics (P1) -------------------------------------------------------------------------
# A hard-rule review of one (ability, target) pair, layered on top of the LEARNED policy for LIVE play only
# (perform_turn_v3's `combat_heuristics` flag — training/eval leave it off, so the policy is still learned raw).
# It reuses the same effect walk as extract_target_features to answer three things the pre-semantic live
# weights are blind to: is this a GUARANTEED KILL (after shield + DR), does the move do LITERALLY NOTHING, and
# is it walking into mitigation / an armed counter. Returns {is_enemy, kill, waste, penalty}.
const HEUR_PENALTY_ABSORBED := 4.0    # damage fully eaten by shield + DR (deal nothing)
const HEUR_PENALTY_REACTIVE := 3.0    # harmful move into an armed counter / reflect
const HEUR_PENALTY_REDUNDANT := 3.0   # control onto an already-disabled target (re-stun)

func combat_verdict(obs: BotObservation, character, cand: Dictionary, target) -> Dictionary:
	var is_enemy: bool = target.team != character.team
	var ability = cand["ability"]
	var hint := int(ability.bot_damage_hint())
	var damaging: bool = ability.classes.get("Damaging", false)
	var harmful: bool = ability.classes.get("Harmful", false)
	var tags := _tags_for(ability)
	var shield := 0
	var flat_dr := 0
	var shattered := false
	var disabled := false
	var heal_denied := false
	var nondmg_immune := false
	var reactive_armed := false
	for effect in obs.visible_effects(target):
		var et = effect.effect_type
		var mag_i: int = int(effect.mag) if typeof(effect.mag) == TYPE_INT else 0
		match et:
			EffectType.Type.SHIELD: shield += mag_i
			EffectType.Type.DAMAGE_REDUCTION: flat_dr += mag_i
			EffectType.Type.DEF_NEGATE: shattered = true
			EffectType.Type.STUN, EffectType.Type.COST_STUN, EffectType.Type.FALSE_STUN, \
			EffectType.Type.PARALYZE, EffectType.Type.SILENCE, EffectType.Type.TAUNT, \
			EffectType.Type.BLIND, EffectType.Type.ISOLATE:
				disabled = true
			EffectType.Type.IGNORE_NON_DAMAGE: nondmg_immune = true
		if et == EffectType.Type.ISOLATE or et == EffectType.Type.IGNORE_HEALING or et == EffectType.Type.HEAL_CUT:
			heal_denied = true
		if et in REACTIVE_TYPES:
			reactive_armed = true
	# Breaking defense zeroes flat DR (mirrors extract_target_features + the engine), so a shattered target
	# is not read as protected.
	if shattered:
		flat_dr = 0
	var mitigation := shield + flat_dr
	var payload_denied: bool = (((tags & TAG_HEAL) != 0) and heal_denied) or (nondmg_immune and not damaging and is_enemy)
	# A guaranteed kill: enemy, deals damage, and the hit clears current HP PLUS everything mitigating it.
	var kill: bool = is_enemy and hint > 0 and hint >= obs.hp(target) + mitigation
	# "waste" = does literally nothing: a NON-damaging skill whose sole payload is nullified. A damaging skill
	# whose damage is absorbed may still carry a debuff, so that is only PENALIZED below, never vetoed.
	var waste: bool = payload_denied and not damaging
	var penalty := 0.0
	if is_enemy and damaging and hint > 0 and hint <= mitigation and not kill:
		penalty += HEUR_PENALTY_ABSORBED
	if is_enemy and harmful and reactive_armed:
		penalty += HEUR_PENALTY_REACTIVE
	if is_enemy and ((tags & TAG_CONTROL) != 0) and disabled and not damaging:
		penalty += HEUR_PENALTY_REDUNDANT
	return {"is_enemy": is_enemy, "kill": kill, "waste": waste, "penalty": penalty}


## Expand one own_candidates() entry into scored, executable variants:
## SINGLE/COUNT → one per legal target; SELF/ALL/ALL_FACTION → one entry whose
## target features average the full set and whose primary target is the best-
## scoring member (the execute path re-fans AoE from the primary).
## Returns [{character, cand, primary_target, score, phi_a, phi_t}].
func score_candidate(obs: BotObservation, character, cand: Dictionary,
		focus_map: Dictionary, tuning = null) -> Array:
	var e := _entry(character.path_name, cand["ability"].ability_name)
	var phi_a := extract_ability_features(obs, character, cand)
	var base := _dot(shared_w, phi_a) + _dot(e["w"], phi_a)
	# PERSISTENT EXPLORATION: a per-match perturbation of this ability's own weights.
	# Softmax temperature resamples independently at every decision, so it can only
	# discover single good ACTIONS - it will essentially never produce a whole
	# multi-turn sequence like "use the setup skill, then cash it in two turns
	# later", which is exactly how preparation abilities pay off. Perturbing the
	# weights ONCE PER MATCH makes the bot commit to a consistent variant for the
	# whole game, so the outcome can actually credit the strategy.
	if not explore_offsets.is_empty():
		var off = explore_offsets.get(character.path_name + "|" + cand["ability"].ability_name, null)
		if off != null:
			base += _dot(off, phi_a)
	var out: Array = []
	var ttype: int = cand["target_type"]
	if ttype == TargetType.Type.SINGLE or ttype == TargetType.Type.COUNT:
		for target in cand["targets"]:
			var phi_t := extract_target_features(obs, character, cand, target, focus_map)
			var s := base + _dot(shared_tw, phi_t) + _dot(e["tw"], phi_t)
			s = tuned_score(s, character.path_name, cand, tuning)
			if s == -INF:
				continue   # tuning ban: exclude entirely — a -INF score would win argmax ties and NaN softmax
			out.append({"character": character, "cand": cand, "primary_target": target,
				"score": s, "phi_a": phi_a, "phi_t": phi_t})
	else:
		var best_target = null
		var best_sub := -INF
		var acc := PackedFloat64Array()
		acc.resize(TARGET_SCHEMA.size())
		for target in cand["targets"]:
			var phi_t := extract_target_features(obs, character, cand, target, focus_map)
			var sub := _dot(shared_tw, phi_t) + _dot(e["tw"], phi_t)
			if sub > best_sub or best_target == null:
				best_sub = sub
				best_target = target
			for i in range(acc.size()):
				acc[i] += phi_t[i]
		if best_target == null:
			return out
		for i in range(acc.size()):
			acc[i] /= cand["targets"].size()
		var s := base + _dot(shared_tw, acc) + _dot(e["tw"], acc)
		s = tuned_score(s, character.path_name, cand, tuning)
		if s == -INF:
			return out   # tuning ban: exclude entirely
		out.append({"character": character, "cand": cand, "primary_target": best_target,
			"score": s, "phi_a": phi_a, "phi_t": acc})
	return out


## Apply the hand-tuning overlay (spec §7). `tuning` is the parsed
## bot_tuning.json dict or null. Training never calls this with a tuning dict.
func tuned_score(score: float, char_path: String, cand: Dictionary, tuning) -> float:
	if tuning == null or not tuning is Dictionary:
		return score
	# Every shape read is defensive: the server validates admin_set_bot_tuning
	# payloads, but a hand-edited file must degrade to "ignored", never crash
	# the live scoring path.
	var ability_name: String = cand["ability"].ability_name
	var chars = tuning.get("characters", {})
	if chars is Dictionary and chars.has(char_path) and chars[char_path] is Dictionary:
		var ct: Dictionary = chars[char_path]
		var bans = ct.get("banned_abilities", [])
		if bans is Array and ability_name in bans:
			return -INF
		var mults = ct.get("ability_multipliers", {})
		if mults is Dictionary and (mults.get(ability_name) is float or mults.get(ability_name) is int):
			score *= float(mults[ability_name])
		var offs = ct.get("ability_offsets", {})
		if offs is Dictionary and (offs.get(ability_name) is float or offs.get(ability_name) is int):
			score += float(offs[ability_name])
	var g = tuning.get("global", {})
	if not g is Dictionary:
		return score
	var classes: Dictionary = cand["ability"].classes
	if classes.get("Harmful", false) and (g.get("aggression") is float or g.get("aggression") is int):
		score *= float(g["aggression"])
	if classes.get("Helpful", false) and (g.get("defense") is float or g.get("defense") is int):
		score *= float(g["defense"])
	if g.get("energy_thrift") is float or g.get("energy_thrift") is int:
		var cost_total := 0
		for v in cand["cost"].values():
			cost_total += int(v)
		score -= float(g["energy_thrift"]) * cost_total
	return score


## Pick from scored entries. temperature <= 0 → argmax (rng-tiebroken).
## `allow_stop`: when true, a STOP sentinel (score 0) competes — under argmax
## it wins only STRICTLY (best < 0), so an untrained all-zero policy still
## acts. Returns the chosen entry, or null for STOP.
func select(scored: Array, temperature: float, rng: RandomNumberGenerator,
		allow_stop: bool = true):
	if scored.is_empty():
		return null
	if temperature <= 0.0:
		var best = null
		var best_score := -INF
		var ties := 0
		for entry in scored:
			if entry["score"] > best_score:
				best_score = entry["score"]
				best = entry
				ties = 1
			elif entry["score"] == best_score:
				ties += 1
				if rng.randi_range(1, ties) == 1:
					best = entry
		if allow_stop and best_score < 0.0:
			return null
		return best
	# Softmax with STOP as an extra 0-score option.
	var max_score := 0.0 if allow_stop else -INF
	for entry in scored:
		max_score = maxf(max_score, entry["score"])
	var weights: Array = []
	var total := 0.0
	for entry in scored:
		var wexp: float = exp((entry["score"] - max_score) / temperature)
		weights.append(wexp)
		total += wexp
	var stop_weight: float = exp((0.0 - max_score) / temperature) if allow_stop else 0.0
	total += stop_weight
	var roll := rng.randf() * total
	var picked = null
	for i in range(scored.size()):
		roll -= weights[i]
		if roll <= 0.0:
			picked = scored[i]
			break
	if picked == null:
		return null   # landed in the STOP mass
	# Correct softmax policy gradient: ∇log π(a|s) ∝ φ_a − E_π[φ]. Attach the
	# centered vectors for the trainer to record — updating with raw φ_chosen
	# inflates state-common components without bound (observed: bias weight
	# +40 after 150 matches; choices unaffected but temperature and tuning
	# scales wrecked). Computed over the same candidate set softmax saw.
	var exp_a := PackedFloat64Array()
	exp_a.resize(FEATURE_SCHEMA.size())
	var exp_t := PackedFloat64Array()
	exp_t.resize(TARGET_SCHEMA.size())
	for i in range(scored.size()):
		var p: float = weights[i] / total
		var pa: PackedFloat64Array = scored[i]["phi_a"]
		var pt: PackedFloat64Array = scored[i]["phi_t"]
		for j in range(mini(exp_a.size(), pa.size())):
			exp_a[j] += p * pa[j]
		for j in range(mini(exp_t.size(), pt.size())):
			exp_t[j] += p * pt[j]
	var grad_a: PackedFloat64Array = picked["phi_a"].duplicate()
	var grad_t: PackedFloat64Array = picked["phi_t"].duplicate()
	for j in range(grad_a.size()):
		grad_a[j] -= exp_a[j]
	for j in range(grad_t.size()):
		grad_t[j] -= exp_t[j]
	picked["phi_a_grad"] = grad_a
	picked["phi_t_grad"] = grad_t
	# Per-ENTRY gradient: the full-set centered vector above is grad-log-pi
	# only for the SHARED layer. For the chosen (character, ability)'s own
	# weights, ∂score/∂w_e is nonzero only on that entry's candidates, so its
	# expectation is restricted to them: φ_chosen − Σ_{c∈entry} π_c φ_c.
	# Without this, every feature constant across the whole candidate set
	# (bias + all state features) centers to exactly 0 and the residual layer
	# can never learn unconditional or state-conditioned offsets. (The −π_cφ_c
	# pushes on UNCHOSEN entries are deliberately omitted — sampled-gradient
	# approximation, keeps one record per action.)
	var ee_a := PackedFloat64Array()
	ee_a.resize(FEATURE_SCHEMA.size())
	var ee_t := PackedFloat64Array()
	ee_t.resize(TARGET_SCHEMA.size())
	for i in range(scored.size()):
		if scored[i]["character"] != picked["character"] \
				or scored[i]["cand"]["ability"] != picked["cand"]["ability"]:
			continue
		var p_e: float = weights[i] / total
		var pa_e: PackedFloat64Array = scored[i]["phi_a"]
		var pt_e: PackedFloat64Array = scored[i]["phi_t"]
		for j in range(mini(ee_a.size(), pa_e.size())):
			ee_a[j] += p_e * pa_e[j]
		for j in range(mini(ee_t.size(), pt_e.size())):
			ee_t[j] += p_e * pt_e[j]
	var egrad_a: PackedFloat64Array = picked["phi_a"].duplicate()
	var egrad_t: PackedFloat64Array = picked["phi_t"].duplicate()
	for j in range(egrad_a.size()):
		egrad_a[j] -= ee_a[j]
	for j in range(egrad_t.size()):
		egrad_t[j] -= ee_t[j]
	picked["phi_a_egrad"] = egrad_a
	picked["phi_t_egrad"] = egrad_t
	return picked


# ---------------------------------------------------------------------------
# Learning (called by the trainer)
# ---------------------------------------------------------------------------

## records: [{char, ability, phi_a/phi_t (full-set centered, for the SHARED
## layer), phi_a_e/phi_t_e (entry-centered, for the per-ability layer), G}].
## Two-pass: all advantages are computed against the baselines AS OF CALL
## ENTRY, then weights update, then the baseline EMAs move — otherwise later
## records in the same match have their advantage eaten by earlier ones (and
## in self-play, by the OTHER side's anticorrelated returns).
## Draw a fresh per-match exploration perturbation for the given characters' kits.
## sigma is in weight units (established weights run ~0.1-1.0, so 0.25 is a real
## but not deranged personality shift). Call once at match start; clear at match end.
##
## Only PER-ENTRY weights are perturbed, never `shared_w`: the shared layer is the
## part that is already well-trained and generalises, while the per-entry table is
## the data-starved part (median ~2 updates) where character-specific tricks would
## live. Perturbing shared would just make the bot globally erratic.
func sample_exploration(character_abilities: Array, sigma: float, rng: RandomNumberGenerator) -> void:
	explore_offsets.clear()
	if sigma <= 0.0:
		return
	for pair in character_abilities:
		var key: String = str(pair[0]) + "|" + str(pair[1])
		var off := PackedFloat64Array()
		off.resize(FEATURE_SCHEMA.size())
		for i in range(off.size()):
			off[i] = rng.randfn(0.0, sigma)
		explore_offsets[key] = off

func clear_exploration() -> void:
	explore_offsets.clear()


func apply_returns(records: Array):
	var g0 := global_baseline
	var b0 := {}
	for r in records:
		if not b0.has(r["char"]):
			b0[r["char"]] = baselines.get(r["char"], 0.0)
		r["_adv"] = float(r["G"]) - g0 - float(b0[r["char"]])
	for r in records:
		var e := _entry(r["char"], r["ability"])
		var adv: float = r["_adv"]
		var lr: float = lr0 / (1.0 + float(e["updates"]) / lr_tau)
		var lr_s: float = lr0 / (1.0 + shared_updates / shared_lr_tau)
		var w: PackedFloat64Array = e["w"]
		var tw: PackedFloat64Array = e["tw"]
		var phi_a: PackedFloat64Array = r["phi_a"]
		var phi_t: PackedFloat64Array = r["phi_t"]
		var phi_a_e: PackedFloat64Array = r.get("phi_a_e", r["phi_a"])
		var phi_t_e: PackedFloat64Array = r.get("phi_t_e", r["phi_t"])
		for i in range(mini(shared_w.size(), phi_a.size())):
			shared_w[i] += lr_s * adv * phi_a[i]
		for i in range(mini(shared_tw.size(), phi_t.size())):
			shared_tw[i] += lr_s * adv * phi_t[i]
		for i in range(mini(w.size(), phi_a_e.size())):
			w[i] += lr * adv * phi_a_e[i]
		for i in range(mini(tw.size(), phi_t_e.size())):
			tw[i] += lr * adv * phi_t_e[i]
		e["w"] = w
		e["tw"] = tw
		e["updates"] = float(e["updates"]) + 1.0
		shared_updates += 1.0
	for r in records:
		global_baseline += global_baseline_beta * (float(r["G"]) - global_baseline)
		var b: float = baselines.get(r["char"], 0.0)
		baselines[r["char"]] = b + baseline_beta * ((float(r["G"]) - global_baseline) - b)


# ---------------------------------------------------------------------------
# Merge (orchestrator: fold worker checkpoints into the next generation)
# ---------------------------------------------------------------------------

## Update-count-weighted average of worker policies. Valid because workers all
## start a round from the SAME parent checkpoint, so averaging weights equals
## averaging their gradient deltas (federated averaging for linear models).
## `base` is that parent: update COUNTS are merged as base + Σ(worker − base)
## and weights are averaged by each worker's DELTA — summing absolute counts
## (the first implementation) inflated them ~N× per round and crushed the lr
## schedule by round 3.
static func merge(inputs: Array, base = null) -> BotPolicyV3:
	var out := BotPolicyV3.new()
	var max_gen := 0
	var base_matches: int = base.trained_matches if base != null else 0
	var base_shared: float = base.shared_updates if base != null else 0.0
	var matches_delta := 0
	var shared_delta := 0.0
	var deltas: Array = []
	for p in inputs:
		max_gen = maxi(max_gen, p.generation)
		matches_delta += maxi(0, p.trained_matches - base_matches)
		var d: float = maxf(0.0, p.shared_updates - base_shared)
		deltas.append(d)
		shared_delta += d
		out.global_baseline += p.global_baseline / inputs.size()
	out.generation = max_gen + 1
	out.trained_matches = base_matches + matches_delta
	out.shared_updates = base_shared + shared_delta
	var shared_norm: float = shared_delta if shared_delta > 0.0 else float(inputs.size())
	for j in range(out.shared_w.size()):
		var acc := 0.0
		for i in range(inputs.size()):
			acc += (deltas[i] if shared_delta > 0.0 else 1.0) * inputs[i].shared_w[j]
		out.shared_w[j] = acc / shared_norm
	for j in range(out.shared_tw.size()):
		var acc := 0.0
		for i in range(inputs.size()):
			acc += (deltas[i] if shared_delta > 0.0 else 1.0) * inputs[i].shared_tw[j]
		out.shared_tw[j] = acc / shared_norm

	# Per-character baselines: plain average across the workers that have one.
	var baseline_chars := {}
	for p in inputs:
		for char_path in p.baselines:
			baseline_chars[char_path] = true
	for char_path in baseline_chars:
		var acc := 0.0
		var n := 0
		for p in inputs:
			if p.baselines.has(char_path):
				acc += float(p.baselines[char_path])
				n += 1
		out.baselines[char_path] = acc / maxf(n, 1)

	# Entries: union, weighted by per-entry update DELTAS over the base.
	var entry_keys := {}
	for p in inputs:
		for char_path in p.entries:
			for ability_name in p.entries[char_path]:
				entry_keys["%s%s" % [char_path, ability_name]] = [char_path, ability_name]
	for key in entry_keys:
		var char_path: String = entry_keys[key][0]
		var ability_name: String = entry_keys[key][1]
		var base_u := 0.0
		if base != null and base.entries.has(char_path) and base.entries[char_path].has(ability_name):
			base_u = float(base.entries[char_path][ability_name]["updates"])
		var delta_u := 0.0
		var holders: Array = []
		var holder_deltas: Array = []
		for p in inputs:
			if p.entries.has(char_path) and p.entries[char_path].has(ability_name):
				var h: Dictionary = p.entries[char_path][ability_name]
				holders.append(h)
				var d: float = maxf(0.0, float(h["updates"]) - base_u)
				holder_deltas.append(d)
				delta_u += d
		var e := out._entry(char_path, ability_name)
		var norm: float = delta_u if delta_u > 0.0 else float(holders.size())
		var w: PackedFloat64Array = e["w"]
		var tw: PackedFloat64Array = e["tw"]
		for i in range(holders.size()):
			var wgt: float = (holder_deltas[i] if delta_u > 0.0 else 1.0) / norm
			var hw: PackedFloat64Array = holders[i]["w"]
			var htw: PackedFloat64Array = holders[i]["tw"]
			for j in range(mini(w.size(), hw.size())):
				w[j] += wgt * hw[j]
			for j in range(mini(tw.size(), htw.size())):
				tw[j] += wgt * htw[j]
		e["w"] = w
		e["tw"] = tw
		e["updates"] = base_u + delta_u
	return out


# ---------------------------------------------------------------------------
# Persistence (name-keyed on disk, packed arrays in memory)
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var out_entries := {}
	for char_path in entries:
		var char_out := {}
		for ability_name in entries[char_path]:
			var e: Dictionary = entries[char_path][ability_name]
			var w_named := {}
			var tw_named := {}
			for i in range(FEATURE_SCHEMA.size()):
				w_named[FEATURE_SCHEMA[i]] = e["w"][i]
			for i in range(TARGET_SCHEMA.size()):
				tw_named[TARGET_SCHEMA[i]] = e["tw"][i]
			char_out[ability_name] = {"w": w_named, "tw": tw_named, "updates": e["updates"]}
		out_entries[char_path] = char_out
	var shared_w_named := {}
	var shared_tw_named := {}
	for i in range(FEATURE_SCHEMA.size()):
		shared_w_named[FEATURE_SCHEMA[i]] = shared_w[i]
	for i in range(TARGET_SCHEMA.size()):
		shared_tw_named[TARGET_SCHEMA[i]] = shared_tw[i]
	return {
		"format": FORMAT, "version": VERSION,
		"generation": generation, "trained_matches": trained_matches,
		"feature_schema": FEATURE_SCHEMA, "target_schema": TARGET_SCHEMA,
		"shared": {"w": shared_w_named, "tw": shared_tw_named, "updates": shared_updates},
		"global_baseline": global_baseline,
		"baselines": baselines, "entries": out_entries,
	}


## Returns null on a format mismatch — callers must treat null as "no valid
## policy" (the live server falls back to the contextual bot; the trainer
## refuses to run). Returning a silently-fresh policy here once meant a
## corrupt bot_policy.json would replace the trained live bot with
## uniform-random play.
static func from_dict(data: Dictionary):
	if data.get("format", "") != FORMAT:
		push_error("[policy-v3] Unrecognized format '%s' — refusing to load" % data.get("format", ""))
		return null
	var policy := BotPolicyV3.new()
	policy.generation = int(data.get("generation", 0))
	policy.trained_matches = int(data.get("trained_matches", 0))
	policy.global_baseline = float(data.get("global_baseline", 0.0))
	for char_path in data.get("baselines", {}):
		policy.baselines[char_path] = float(data["baselines"][char_path])
	var unknown := {}
	var shared: Dictionary = data.get("shared", {})
	if not shared.is_empty():
		policy.shared_updates = float(shared.get("updates", 0.0))
		for fname in shared.get("w", {}):
			var idx := FEATURE_SCHEMA.find(fname)
			if idx >= 0:
				policy.shared_w[idx] = float(shared["w"][fname])
			else:
				unknown[fname] = true
		for fname in shared.get("tw", {}):
			var idx := TARGET_SCHEMA.find(fname)
			if idx >= 0:
				policy.shared_tw[idx] = float(shared["tw"][fname])
			else:
				unknown[fname] = true
	for char_path in data.get("entries", {}):
		for ability_name in data["entries"][char_path]:
			var stored: Dictionary = data["entries"][char_path][ability_name]
			var e := policy._entry(char_path, ability_name)
			var w: PackedFloat64Array = e["w"]
			var tw: PackedFloat64Array = e["tw"]
			for fname in stored.get("w", {}):
				var idx := FEATURE_SCHEMA.find(fname)
				if idx >= 0:
					w[idx] = float(stored["w"][fname])
				else:
					unknown[fname] = true
			for fname in stored.get("tw", {}):
				var idx := TARGET_SCHEMA.find(fname)
				if idx >= 0:
					tw[idx] = float(stored["tw"][fname])
				else:
					unknown[fname] = true
			e["w"] = w
			e["tw"] = tw
			e["updates"] = float(stored.get("updates", 0.0))
	for fname in unknown:
		push_warning("[policy-v3] Dropping weight for unknown feature '%s' (schema changed)" % fname)
	return policy


func save_to_path(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[policy-v3] Cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true


## Missing file -> fresh policy (a legitimate cold start). Existing-but-
## unreadable/invalid file -> null (see from_dict).
static func load_from_path(path: String):
	if not FileAccess.file_exists(path):
		return BotPolicyV3.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[policy-v3] Cannot read %s" % path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("[policy-v3] %s is not valid JSON — refusing to load" % path)
		return null
	return from_dict(parsed)
