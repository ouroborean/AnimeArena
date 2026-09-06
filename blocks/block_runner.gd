extends RefCounted
class_name BlockRunner

# ============================================================================
# The INTERPRETER. Walks a validated block tree and performs it using the exact
# same engine primitives a hand-written GDScript ability calls
# (Character.resolve_damage / resolve_healing / add_allied_effect /
# add_hostile_effect, and the Effect.* factories).
#
# That is the whole trick: authored abilities are not a parallel rules engine.
# They funnel into the same code paths, so every existing interaction — invuln,
# counters, reflect, shields, death-cleanse, Blood Spear interception, the lot —
# applies to them for free and stays bug-for-bug consistent with hand-coded kits.
#
# Runtime posture: NEVER crash a live match. A malformed block that slipped past
# BlockValidator warns once and is skipped; it does not abort the ability, the
# turn, or the match.
# ============================================================================

var ability            # the ScriptedAbility that owns this run (effect source)
var battle
var user
var _depth := 0
# Set when this run is a trigger payload: "target" then means the character who
# tripped the trigger, not the (stale) targeter of the original cast.
var _explicit_targets = null
# PAYLOAD ADDRESSING (see BlockSchema.PAYLOAD_SELECTORS). Both are null outside a payload, which
# is the whole guard: `holder`/`affected` then resolve to NOBODY rather than to the caster.
var _payload_holder = null      # context.effect.target — the character carrying the effect
var _payload_affected = null    # context.target — the character the event happened to
# THE EVENT MAGNITUDE the payload is reacting to (QueryContext.value): damage received/dealt or
# healing given. null outside a payload AND on the hooks that carry no magnitude (a counter check, a
# tick) — which is exactly why the `event` reading is validator-gated to payloads and floors at 0
# here: out here there is no event to read. Bound by set_payload_addressing alongside holder/affected.
var _payload_event = null
# RUNAWAY BUDGET — the runtime half of the `repeat` guard, counted in blocks EXECUTED rather than
# blocks WRITTEN. BlockValidator._count_blocks multiplies a repeat's body by its `times` and
# refuses a tree whose product exceeds max_blocks_per_ability, but the validator can be bypassed by
# a hand-edited file on disk and this cannot: nesting `repeat` inside `repeat` at the depth limit
# is 12^4 executions of one block from a tree that LOOKS tiny, inside turn resolution, on a live
# match. The number is the validator's own ceiling, so a tree that passed validation can never
# reach it and nothing legitimate changes.
var _budget := 0
# CHANNEL / CONTROL. "" for every run except a TOP-LEVEL cast of a skill that declared the flag —
# set_channel is called from ScriptedAbility.execute and from nowhere else, which is the whole
# guard: a trigger payload builds its own BlockRunner, so a channelled skill does not re-plant its
# cancel every time one of its own triggers fires.
var _channel_mode := ""
var _channel_effects: Array = []

func _init(owner_ability, battle_ref, user_ref):
	ability = owner_ability
	battle = battle_ref
	user = user_ref

# --- entry point ------------------------------------------------------------
func run(blocks: Array) -> void:
	_depth = 0
	_budget = BlockSchema.LIMITS["max_blocks_per_ability"]
	_channel_effects = []
	_run_list(blocks)
	_close_channel()

# Which cancel holder a top-level cast plants over everything it applied. Called ONLY by
# ScriptedAbility.execute; see _channel_mode.
func set_channel(mode: String) -> void:
	_channel_mode = mode

# THE ACCUMULATOR, closed once at the end of the cast. All 16 shipped call sites cancel
# EVERYTHING the skill applied and none of them is selective (gogeta1, gray6, madoka2, kitara1,
# genos3, korra8, maka3, nonon3, sakura2, shiro4, tanjiro2, ...), so there is nothing to label:
# the list IS the cast.
#
# THE VALIDITY FILTER IS LOAD-BEARING, not defensive tidiness. Two ordinary outcomes free an
# Effect node between building it and getting here:
#   * the application was REJECTED (target invulnerable, dead, ignoring the skill) and
#     Character._free_unapplied_effect queue_free()d it;
#   * it MERGED into an identical stored effect and effect_storage_component queue_free()d it.
# Either way a raw append leaves a dangling reference, and Character._end_cancel_effects reading
# `.removed` off it raises "Invalid access ... on a previously freed object" — mid-turn, in a live
# match. That function already guards itself the same way (scripts/character_component.gd:302-307);
# filtering here as well means the holder never carries a corpse in the first place.
func _close_channel() -> void:
	if _channel_mode.is_empty():
		return
	var live: Array = []
	for e in _channel_effects:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			live.append(e)
	_channel_effects = []
	# Nothing landed — every application was refused, or the skill applies nothing at all. A holder
	# guarding an empty list is a pip that promises a channel with no channel behind it.
	if live.is_empty():
		return
	# -1, matching every shipped channel_cancel: the holder has to outlive the effects it guards or
	# they become unbreakable, and it is ENDED EXPLICITLY rather than by expiry — check_cancels on a
	# stun/death/banish/seal, and cancel_channels on the user's next non-"Preserves Channel" action.
	var holder = Effect.channel_cancel(-1, ability.ability_name, live) if _channel_mode == "channel" else Effect.control_cancel(-1, ability.ability_name, live)
	holder.set_source(ability)
	Character.add_allied_effect(_ctx(), user, user, holder)

func _run_list(blocks) -> void:
	if not blocks is Array:
		return
	if _depth > BlockSchema.LIMITS["max_nesting_depth"]:
		push_warning("[blocks] nesting limit hit in '%s' — deeper blocks skipped" % ability.ability_name)
		return
	for b in blocks:
		if b is Dictionary:
			_run_block(b)

func _run_block(b: Dictionary) -> void:
	# Charged BEFORE the `when` guard: a skipped block still cost a condition evaluation, and a
	# runaway shape whose guard reads false is still a runaway shape.
	if _budget <= 0:
		# Warn ONCE, on the first block actually refused — a tree that executes exactly the ceiling
		# is legal and must not log anything. -1 is the "already warned" state.
		if _budget == 0:
			_budget = -1
			push_warning("[blocks] block budget exhausted in '%s' — the rest of the tree is skipped" % ability.ability_name)
		return
	_budget -= 1
	# `when` guard: any block may carry a condition, evaluated ONCE for the whole block.
	#
	# PHASE F retires the old special case. The legacy string filtered selectors (any_enemy/...) are
	# SUGAR for a Layer-2 selector object whose `where` IS this block's `when` — so for THEM the
	# `when` is the per-candidate filter and must not also gate the block (double-evaluating it turns
	# "hit each hurt enemy" into "hit each hurt enemy, but only if at least one is hurt"). The OBJECT
	# form (`to` is a Dictionary) carries its own `where`, so its `when` is always the whole-block
	# guard — a block now has BOTH. `_when_is_per_candidate_filter` is true only for the legacy string
	# sugar; it replaces the old `_is_filtered_block` flag, which the desugaring makes unnecessary.
	# A branching group (`group` + `else`) evaluates its OWN `when` inside the op so the roll is spent
	# EXACTLY ONCE — checking it here as well would double-fire a `chance` guard and let both branches
	# roll independently. Every other block keeps the pre-dispatch gate.
	if b.has("when") and not _when_is_per_candidate_filter(b) and not _is_branching_group(b) and not _check_condition(b["when"]):
		return
	match str(b.get("op", "")):
		"damage":      _op_damage(b)
		"heal":        _op_heal(b)
		"apply":       _op_apply(b)
		"gain_energy": _op_gain_energy(b)
		"cleanse":     _op_cleanse(b)
		"remove":      _op_remove(b)
		"adjust":      _op_adjust(b)
		"break":       _op_break(b)
		"banish":      _op_banish(b)
		"execute":     _op_execute(b)
		"revive":      _op_revive(b)
		"cooldown":    _op_cooldown(b)
		"drain_energy": _op_drain_energy(b)
		"seal":        _op_seal(b)
		"group":
			_depth += 1
			# EITHER/OR when an `else` is present: the `when` is rolled ONCE (above was skipped for this
			# shape) and exactly one branch runs. With no `else` it is the ordinary bundle — the
			# pre-dispatch gate already applied its `when`, so `blocks` runs unconditionally here.
			if b.get("else", null) is Array:
				if not b.has("when") or _check_condition(b["when"]):
					_run_list(b.get("blocks", []))
				else:
					_run_list(b.get("else", []))
			else:
				_run_list(b.get("blocks", []))
			_depth -= 1
		"repeat":
			# A group with a count. The body is re-walked from the top each time — not "the same
			# resolution applied N times" — because that is the whole mechanic: every repetition
			# re-resolves its own targets, re-rolls its own `chance`, and pays shields, damage
			# reduction, the damage floor and every receive-trigger again.
			var reps := clampi(_reading_or_int(b.get("times", 1)), 0, BlockSchema.LIMITS["max_repeat_times"])
			_depth += 1
			for _i in range(reps):
				if _budget <= 0:
					break
				_run_list(b.get("blocks", []))
			_depth -= 1
		_:
			push_warning("[blocks] unknown op '%s' in '%s' — skipped" % [str(b.get("op","")), ability.ability_name])

# --- context ----------------------------------------------------------------
func _ctx():
	return QueryContext.from_game_state(user, battle)

# --- selectors --------------------------------------------------------------
# Does this block's `to` consume the block's `when` as its PER-CANDIDATE filter (rather than a
# whole-block guard)? True ONLY for the legacy string filtered selectors (any_enemy/any_ally/
# any_character), which are sugar for a selector object with that `when` as its `where`. An OBJECT
# `to` carries its own `where` and never consumes `when`. This is the desugared replacement for the
# retired `_is_filtered_block`.
func _when_is_per_candidate_filter(b: Dictionary) -> bool:
	var to = b.get("to", "")
	return to is String and BlockSchema.FILTERED_SELECTORS.has(str(to))

# A `group` that carries an `else` owns its own `when` (it rolls it once and picks a branch), so the
# pre-dispatch gate must not evaluate it — see the ONE-roll note on OPS' group row.
func _is_branching_group(b: Dictionary) -> bool:
	return str(b.get("op", "")) == "group" and b.get("else", null) is Array

# Every op resolves its targets through here. PHASE F: a Dictionary `to` is a Layer-2 selector object
# (pool x where x pick x order); a string `to` keeps the legacy path, where the filtered selectors
# get the block's `when` as their per-candidate filter without each op knowing about it.
func _block_targets(b: Dictionary, dflt: String) -> Array:
	var to = b.get("to", dflt)
	if to is Dictionary:
		return _resolve_selector_object(to)
	return _resolve_targets(to, b.get("when", null), _bypass_gate(b))

# --- PHASE F LAYER 2: the block selector object -----------------------------------------------
# POOL x WHERE x PICK x ORDER, composed with A2 mandatorily. The exact desugaring of a string
# filtered selector: `to: "any_enemy"` + `when: C` IS `to: {"pool":"enemies","where":[C]}`.
func _resolve_selector_object(obj: Dictionary) -> Array:
	var pool_name := str(obj.get("pool", "target"))
	var base := _resolve_pool(pool_name)
	# A2, MANDATORY. Any pool NOT sourced from targeter.targets / self / the revive pool re-runs the
	# engine's own targeting predicate, with `bypassing` as the single opt-out (the ability's own
	# Bypassing class is the default, exactly as _bypass_gate reads it for the string ops).
	if pool_name in BlockSchema.POOL_GATED:
		var bp = obj.get("bypassing", null)
		var gate = bp if bp is bool else _ability_bypasses()
		base = _legal_pool(base, gate)
	# WHERE — the per-candidate predicate list, AND-ed, same subject binding as an eligibility `only`.
	var filtered: Array = []
	var where = obj.get("where", [])
	for c in base:
		if _where_holds(where, c):
			filtered.append(c)
	# ORDER — clicked_first leads with main_target so a main_target-aware block agrees with the click.
	if str(obj.get("order", "pool")) == "clicked_first":
		filtered = _order_clicked_first(filtered)
	# PICK — narrow to who is actually hit.
	return _apply_pick(filtered, str(obj.get("pick", "all")), str(obj.get("measure", "hp")), int(obj.get("count", 1)))

# The base population behind a POOL name, dead/banished dropped (except dead_allies, which is the
# revive pool and IS the dead). target/main_target/other_targets read the live targeter (or the
# explicit payload targets); the rest read the roster.
func _resolve_pool(name: String) -> Array:
	var out: Array = []
	var src = _explicit_targets if _explicit_targets != null else user.targeter.targets
	match name:
		"target":
			for t in src:
				if _alive(t):
					out.append(t)
		"main_target":
			var mt = user.targeter.main_target
			if mt != null and _alive(mt):
				out.append(mt)
		"other_targets":
			var mt2 = user.targeter.main_target
			for t in src:
				if _alive(t) and t != mt2:
					out.append(t)
		"user":
			if _alive(user):
				out.append(user)
		"allies":
			for c in user.team.characters:
				if _alive(c):
					out.append(c)
		"other_allies":
			for c in user.team.characters:
				if c != user and _alive(c):
					out.append(c)
		"enemies":
			for c in _enemy_team():
				if _alive(c):
					out.append(c)
		"everyone":
			for c in user.team.characters:
				if _alive(c):
					out.append(c)
			for c in _enemy_team():
				if _alive(c):
					out.append(c)
		"dead_allies":
			# The one pool that keeps the dead: a revive target must be reachable, and _alive drops it.
			# Banished stays out (a banished character is off the board, not merely dead).
			for c in user.team.characters:
				if c != null and is_instance_valid(c) and c.dead and not c.banished:
					out.append(c)
		_:
			push_warning("[blocks] unknown pool '%s' in '%s' — no targets" % [name, ability.ability_name])
	return out

func _where_holds(where, c) -> bool:
	if not where is Array:
		return true
	for cond in where:
		if not _check_condition(cond, c):
			return false
	return true

# Lead the list with the primary target so it becomes main_target (TargeterComponent.add_target makes
# the first entry the main target); the rest keep their order.
func _order_clicked_first(list: Array) -> Array:
	var mt = user.targeter.main_target
	if mt == null or not list.has(mt):
		return list
	var out: Array = [mt]
	for c in list:
		if c != mt:
			out.append(c)
	return out

# PICK. all -> everyone; random -> Fisher-Yates without replacement; lowest/highest -> the extremal
# `measure`, TIES INCLUDED (hisoka6's shape) and in the incoming order so a clicked_first lead
# survives.
func _apply_pick(list: Array, pick: String, measure: String, count: int) -> Array:
	match pick:
		"random":
			return _pick_random(list, count)
		"lowest", "highest":
			return _pick_extreme(list, measure, pick == "lowest")
	return list

# Partial Fisher-Yates over the seeded die, WITHOUT replacement: the drawn characters are DISTINCT,
# and a replay re-derives the same sequence from battle.roll. The old random_enemy was a single roll
# with no memory, so three of them could all hit the same enemy; this cannot within one draw.
func _pick_random(list: Array, count: int) -> Array:
	var arr := list.duplicate()
	var n: int = clampi(count, 0, arr.size())
	var out: Array = []
	for i in range(n):
		var j: int = battle.roll(i, arr.size() - 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		out.append(arr[i])
	return out

func _pick_extreme(list: Array, measure: String, lowest: bool) -> Array:
	if list.is_empty():
		return list
	var best: int = _char_value(list[0], measure)
	for c in list:
		var v: int = _char_value(c, measure)
		if (lowest and v < best) or (not lowest and v > best):
			best = v
	var out: Array = []
	for c in list:
		if _char_value(c, measure) == best:
			out.append(c)
	return out

# The PER-CHARACTER measure for pick:lowest/highest and the Layer-1 eligibility pick. Exposed so
# ScriptedAbility.target can rank eligibility candidates through the SAME per-character evaluator the
# block selector uses — NOT _resolve_reading, which folds a selection to one number.
func char_measure(c, measure: String) -> int:
	return _char_value(c, measure)

# The pool-re-validation gate for one block. `null` means "do not re-validate at all" — that
# is every op outside BlockSchema.REVALIDATED_OPS, and it is also what a CONDITION's selector
# slots get, because reading state off a character is not targeting it.
#
# TWO LAYERS, ONE ANSWER. The ability-level "Bypassing" CLASS is the skill's declaration that it
# ignores invulnerability, and ScriptedAbility.target already hands it to the targeting helpers.
# If it stopped there a Bypassing AoE would SELECT an invulnerable enemy and then silently drop
# it here — exactly the kind of split A2 exists to remove — so the class is also the DEFAULT for
# every block. The per-block field overrides it in BOTH directions: an author can mark a skill
# Bypassing and still have one block respect invulnerability (`bypassing: false`), or leave the
# skill normal and let one block reach through (`bypassing: true`).
func _bypass_gate(b: Dictionary):
	if not str(b.get("op", "")) in BlockSchema.REVALIDATED_OPS:
		return null
	# A non-bool `bypassing` is NOT an override. This one weakens a guard, and a hand-edited
	# file never met the validator: bool("no") is TRUE in GDScript, so coercing here would let
	# a typo switch the whole check off — it falls through to the ability's own default instead.
	var p = b.get("bypassing", null)
	if p is bool:
		return p
	return _ability_bypasses()

# The ability-level class, read the same way Ability._skill_pierces_invuln reads it
# (abilities/scripts/ability_component.gd:443). classes.get(), not classes[], so an ability
# whose dict predates the key reads false instead of crashing mid-turn.
func _ability_bypasses() -> bool:
	if ability == null or not "classes" in ability:
		return false
	return bool(ability.classes.get("Bypassing", false))

# A2. Drop candidates the targeting system would never have offered this ability. This runs
# ONLY on pools BlockRunner built itself — see BlockSchema.REVALIDATED_OPS for why, and why
# `target` and `user` are exempt.
#
# Hostile or allied is decided PER CANDIDATE by user.is_hostile(c), the same question
# _op_apply already asks to pick between add_hostile_effect and add_allied_effect. That also
# gives `any_character` (a mixed pool) the right predicate for each half without a special case.
#
# The allied side is checked UNCONDITIONALLY, not only for helpful blocks: can_allied_target
# is the engine's own ally-targeting predicate (abilities/scripts/ability_component.gd:853),
# default_allied_target_function applies it to EVERY ally-targeted skill regardless of the
# Helpful class, and an isolated ally is therefore unclickable for all of them. Gating it on
# intent would be a rule the game does not have — in the permissive direction, which is the
# same mistake as inventing a restriction.
func _legal_pool(pool: Array, gate) -> Array:
	if gate == null:
		return pool
	var bypass := bool(gate)
	var ctx = _ctx()
	var out: Array = []
	for c in pool:
		var ok: bool
		if user.is_hostile(c):
			ok = Condition.can_hostile_target(user, c, ability, bypass).satisfied(ctx)
		else:
			ok = Condition.can_allied_target(user, c, bypass).satisfied(ctx)
		if ok:
			out.append(c)
	return out

# Resolves a selector to a live, non-dead character list. Defaults to the
# skill's own targets, which is what the overwhelming majority of blocks want.
# `filter_cond` is only consulted for the FILTERED_SELECTORS.
# `gate` is the re-validation gate from _bypass_gate: null (don't), false (check), true
# (check with the invuln/isolation clause bypassed).
func _resolve_targets(sel, filter_cond = null, gate = null) -> Array:
	var key := str(sel) if sel != null else "target"
	var out: Array = []
	if BlockSchema.FILTERED_SELECTORS.has(key):
		return _resolve_filtered(key, filter_cond, gate)
	match key:
		"target":
			# In a trigger payload the caster's targeter is stale (the cast that
			# placed this effect finished turns ago), so "target" means whoever
			# tripped the trigger — set by set_explicit_targets.
			var src = _explicit_targets if _explicit_targets != null else user.targeter.targets
			for t in src:
				if _alive(t):
					out.append(t)
		"user":
			if _alive(user):
				out.append(user)
		# --- payload addressing ---------------------------------------------------------
		# Both are AT MOST one character, and NEITHER falls back to anything. A dead, banished
		# or freed holder answers [] and the block does nothing — which is the point: the
		# fallback a "sensible default" would reach for is `user`, and `user` in a payload is
		# the effect's APPLIER, so "damage the holder" would silently become "damage myself"
		# the instant the holder died mid-payload.
		#
		# Deliberately NOT run through _legal_pool. That check exists for pools BlockRunner
		# BUILDS out of a team roster (see BlockSchema.REVALIDATED_OPS); these two are handed
		# to us by the engine hook that just fired, exactly as `target` is, and re-filtering
		# them would invent a targeting restriction on a character the event already touched.
		"holder":
			if _alive(_payload_holder):
				out.append(_payload_holder)
		"affected":
			if _alive(_payload_affected):
				out.append(_payload_affected)
		"all_enemies":
			for c in _enemy_team():
				if _alive(c):
					out.append(c)
			out = _legal_pool(out, gate)
		"all_allies":
			for c in user.team.characters:
				if _alive(c):
					out.append(c)
			out = _legal_pool(out, gate)
		"other_allies":
			for c in user.team.characters:
				if c != user and _alive(c):
					out.append(c)
			out = _legal_pool(out, gate)
		"random_enemy":
			var pool := []
			for c in _enemy_team():
				if _alive(c):
					pool.append(c)
			# BEFORE the roll, deliberately. Picking uniformly among the LEGAL targets is what a
			# human player does, and rolling first would hand back a candidate we then have to
			# discard — a silent no-op cast. It DOES change the roll's range, and therefore the
			# seeded stream, versus the pre-A2 build; that is the intended cost of the fix.
			pool = _legal_pool(pool, gate)
			if not pool.is_empty():
				out.append(pool[battle.roll(0, pool.size() - 1)])
		"random_ally":
			var apool := []
			for c in user.team.characters:
				if _alive(c):
					apool.append(c)
			apool = _legal_pool(apool, gate)   # same pre-roll ordering as random_enemy
			if not apool.is_empty():
				out.append(apool[battle.roll(0, apool.size() - 1)])
		_:
			push_warning("[blocks] unknown selector '%s' — defaulting to target" % key)
			for t in user.targeter.targets:
				if _alive(t):
					out.append(t)
	return out

# any_enemy / any_ally / any_character: EVERY living member of the pool for whom the
# condition holds, tested once per candidate WITH THAT CANDIDATE AS THE SUBJECT. That is
# what makes them different from the block-level guard (which asks the question once, for
# the whole block) and from random_* (which pick one).
func _resolve_filtered(key: String, cond, gate = null) -> Array:
	if not cond is Dictionary:
		# The validator rejects this shape, so only a hand-edited file gets here. Hitting
		# nobody is the honest reading — falling back to the whole pool would silently turn
		# a broken filter into an unconditional AoE.
		push_warning("[blocks] '%s' needs an accompanying condition in '%s' — no targets" % [key, ability.ability_name])
		return []
	var out: Array = []
	# Re-validate BEFORE the per-candidate condition, not after: the condition may be `chance`,
	# which spends a seeded roll, and asking "does it hold?" about a character this ability
	# could never have targeted is a roll spent on nobody.
	for c in _legal_pool(_filtered_pool(key), gate):
		if _alive(c) and _check_condition(cond, c):
			out.append(c)
	return out

func _filtered_pool(key: String) -> Array:
	match key:
		"any_enemy":
			return _enemy_team()
		"any_ally":
			return user.team.characters
		"any_character":
			var both: Array = []
			both.append_array(user.team.characters)
			both.append_array(_enemy_team())
			return both
	return []

func _alive(c) -> bool:
	return c != null and is_instance_valid(c) and not (c.dead or c.banished)

func _enemy_team() -> Array:
	if battle.player == null or battle.enemy == null:
		return []
	return battle.enemy.team.characters if user.team == battle.player.team else battle.player.team.characters

# --- conditions -------------------------------------------------------------
# Exposed so ScriptedAbility.extra_usable can reuse the exact same condition
# vocabulary for usage gating (`requires`) that blocks use for `when`.
func check_condition_public(c, subject = null) -> bool:
	return _check_condition(c, subject)

# `subject` is set only when this condition is a FILTERED SELECTOR's per-candidate filter.
# It becomes the condition's default subject, so `{"cond":"hp_below","value":50}` under a
# to:"any_enemy" asks "is THIS enemy below 50", not "is the user below 50".
# An EXPLICIT `on` (or `of`/`vs` on a compare) still resolves normally — that is how an
# author phrases "hit each enemy, but only while the USER is hurt": the same answer for
# every candidate, which is exactly what a per-candidate test of a fixed selector means.
func _check_condition(c, subject = null) -> bool:
	if not c is Dictionary:
		return true
	var on := _subject_targets(c, "on", subject, "user")
	match str(c.get("cond", "")):
		"has_effect":
			for t in on:
				if _presence(c, t):
					return true
			return false
		"not_has_effect":
			for t in on:
				if _presence(c, t):
					return false
			return true
		"hp_below":
			for t in on:
				if t.health.hp < int(c.get("value", 0)):
					return true
			return false
		"hp_above":
			for t in on:
				if t.health.hp > int(c.get("value", 0)):
					return true
			return false
		"stacks_at_least":
			for t in on:
				# MARK is the DEFAULT here, not the rule any more. It used to be hardcoded, which
				# made a stacking Shield, DoT or cost modifier — every one of which the engine
				# counts with the same stack_count() — uncountable from an authored condition.
				# Keeping MARK as the default is what stops the new field from changing what an
				# already-saved character means.
				var eff = t.has_effect(str(c.get("name", "")), _presence_type(c, EffectType.Type.MARK), _presence_user(c))
				if eff != null and eff.stack_count() >= int(c.get("value", 1)):
					return true
			return false
		"chance":
			return battle.roll(1, 100) <= int(c.get("percent", 100))
		"energy_at_least":
			# Energy is a TEAM pool: read the FIRST resolved member's team once (the same single-read
			# the `energy` reading does), not a per-head sum. `of` takes the per-candidate subject the
			# way every other slot does, so under a filtered selector it asks about THAT candidate's team.
			var of := _subject_targets(c, "of", subject, "all_enemies")
			if of.is_empty():
				return false
			var team = of[0].team
			if team == null or team.energy == null:
				return false
			return int(team.energy.total_available()) >= int(c.get("value", 0))
		"cost_color_at_least":
			# Reads THIS skill's own resolved cost — ability.cost() already folds in every COST_MOD /
			# COST_CHANGE / COLOR_CHANGE on the caster (ability_component.gd:284) — and asks whether the
			# named colour component meets the threshold. The Cost-Random idiom: cost()[RANDOM] >= 1 is
			# true only once an enemy has taxed the caster. `subject` is ignored: the cost is a property
			# of the ability, identical for every candidate a filtered selector might bind.
			if ability == null or user == null or user.battle == null:
				return false
			var cid := BlockSchema.energy_colour_id(str(c.get("colour", "")))
			if cid < 0:
				return false
			var cost_dict = ability.cost()
			return int(cost_dict.get(cid, 0)) >= int(c.get("value", 1))
		"compare":
			return _cond_compare(c, subject)
	push_warning("[blocks] unknown condition '%s' — treated as true" % str(c.get("cond","")))
	return true

# --- presence: "is that effect there?" --------------------------------------
# THE PAIR. `effect` narrows the match to one EffectType, `by` narrows it to the acting user's own
# copy, and both are OPTIONAL — with neither, this is bit-for-bit the old has_any_effect(name) and
# no saved character changes meaning.
#
# They are one feature because the ENGINE only has one entry point: has_effect(name, type, user)
# matches all three at once (scripts/effect_storage_component.gd:67-71), and there is no
# name+user-without-type call anywhere to fall back on. So `by` without `effect` cannot be answered
# by the engine at all, and the validator rejects that shape rather than letting it read as "any".
func _presence(c: Dictionary, t) -> bool:
	var nm := str(c.get("name", ""))
	if not c.has("effect"):
		return t.has_any_effect(nm)
	var want := _presence_type(c, -1)
	if want < 0:
		# A type name the enum does not have — only reachable from a hand-edited file, since the
		# validator checks it against the same derived list. FAIL CLOSED: an unreadable filter must
		# match FEWER effects than the author asked for, never fall back to matching everything.
		push_warning("[blocks] condition: unknown effect type '%s' in '%s' — reads as absent" % [str(c["effect"]), ability.ability_name])
		return false
	return t.has_effect(nm, want, _presence_user(c)) != null

# The EffectType a presence condition matches, or `dflt` when the author named none.
func _presence_type(c: Dictionary, dflt: int) -> int:
	if not c.has("effect"):
		return dflt
	return BlockSchema.immunity_effect_id(str(c["effect"]))

# WHOSE copy counts. "mine" is the acting user of the block that carries this condition — inside a
# trigger payload that is the effect's APPLIER, which is the same character `user` means everywhere
# else in a payload, so the two readings cannot disagree. Anything else (including the absent
# default) is null, which has_effect reads as "anybody's".
func _presence_user(c: Dictionary):
	return user if str(c.get("by", "any")) == "mine" else null

# Resolve one of a condition's selector slots. With a per-candidate `subject` and NO explicit
# key, the candidate itself is the answer; otherwise this is the ordinary selector lookup.
func _subject_targets(c: Dictionary, key: String, subject, dflt: String) -> Array:
	if subject != null and not c.has(key):
		return [subject]
	return _resolve_targets(c.get(key, dflt))

# Relational predicates. Two shapes share one condition because they share one
# question ("how do these characters compare?"): a GROUP fold (all_equal /
# any_differ) over the whole resolved selector, and a pairwise test of the first
# resolved character against a constant (`than`) or another selector (`vs`).
func _cond_compare(c: Dictionary, subject = null) -> bool:
	# A reading OBJECT as the value: it already folds the whole selection to ONE number
	# (the same single-number-per-selection shape alive_count has), so it compares pairwise
	# against `than` and never folds a group or takes a `vs`. The validator enforces that shape.
	if c.get("value", null) is Dictionary:
		return _numeric_compare(str(c.get("op", "eq")), _resolve_reading(c["value"]), int(c.get("than", 0)))
	var value := str(c.get("value", "hp"))
	var op := str(c.get("op", "eq"))
	# `of` is compare's subject slot, so it takes the per-candidate default the way `on`
	# does everywhere else. `vs` is deliberately NOT defaulted to the candidate: it is the
	# other side of the comparison, and defaulting both to the same character would make
	# every pairwise compare trivially equal.
	var group := _subject_targets(c, "of", subject, "all_enemies")
	# alive_count describes the SELECTION, not a member of it, so it never folds.
	if value == "alive_count":
		var rhs_count := _resolve_targets(c["vs"]).size() if c.has("vs") else int(c.get("than", 0))
		return _numeric_compare(op, group.size(), rhs_count)
	if group.is_empty():
		return false
	if op in BlockSchema.COMPARE_GROUP_OPS:
		var first := _char_value(group[0], value)
		for ch in group:
			if _char_value(ch, value) != first:
				return op == "any_differ"
		return op == "all_equal"
	var lhs := _char_value(group[0], value)
	var rhs := 0
	if c.has("vs"):
		var other := _resolve_targets(c["vs"])
		if other.is_empty():
			return false
		rhs = _char_value(other[0], value)
	else:
		rhs = int(c.get("than", 0))
	return _numeric_compare(op, lhs, rhs)

func _char_value(ch, value: String) -> int:
	match value:
		"hp_percent":
			# max_hp can legitimately be raised mid-match (health caps, buffs), so read
			# it live rather than assuming the 100 every character starts with.
			var cap: int = int(ch.health.max_hp)
			return 0 if cap <= 0 else int(round(100.0 * float(ch.health.hp) / float(cap)))
		"missing_hp":
			# PER-CHARACTER missing HP, for pick:lowest/highest on a `measure`. This is the
			# per-member reading `_resolve_reading` SUMS — kept a per-character scalar here so a
			# pick compares members, not the folded total.
			return maxi(int(ch.health.max_hp) - int(ch.health.hp), 0)
		_:
			return int(ch.health.hp)

func _numeric_compare(op: String, lhs: int, rhs: int) -> bool:
	match op:
		"gt": return lhs > rhs
		"lt": return lhs < rhs
		"eq": return lhs == rhs
	return false

# --- ops --------------------------------------------------------------------
func _op_damage(b: Dictionary) -> void:
	var amount := _amount(b.get("amount", 0))
	if amount <= 0:
		return
	var dtype := BlockSchema.damage_type_id(str(b.get("damage_type", "NORMAL")))
	# Character.resolve_damage returns IMMEDIATELY when owner.used_ability is null
	# (scripts/character_component.gd:2112) — and in a REACTIVE payload it always is, because the cast
	# that planted the trigger finished turns ago. Without this borrow the whole damage block silently
	# did nothing: the validator accepted it, the description promised it, and no damage was ever dealt.
	# _op_heal has always done this; _op_damage was simply missing it.
	var prev = user.used_ability
	var borrowed := prev == null
	if borrowed:
		user.used_ability = ability
	for t in _block_targets(b, "target"):
		Character.resolve_damage(_ctx(), t, amount, dtype)
	if borrowed:
		user.used_ability = null   # put it back exactly as found

func _op_heal(b: Dictionary) -> void:
	var amount := _amount(b.get("amount", 0))
	if amount <= 0:
		return
	# resolve_healing reads owner.used_ability; make sure it is this ability even
	# when the block runs from a trigger callback outside the normal cast path.
	# Same borrow as _op_damage. The old restore line read
	#   user.used_ability = prev if prev != null else user.used_ability
	# which LEAKS: when prev was null it re-assigned the borrowed value instead of clearing it, so the
	# character kept a stale used_ability after the trigger and mis-attributed later damage.
	var prev = user.used_ability
	var borrowed := prev == null
	if borrowed:
		user.used_ability = ability
	for t in _block_targets(b, "target"):
		Character.resolve_healing(_ctx(), t, amount)
	if borrowed:
		user.used_ability = null

func _op_gain_energy(b: Dictionary) -> void:
	var n := clampi(int(b.get("amount", 1)), 0, BlockSchema.LIMITS["max_energy_gain"])
	# No colour = the historical behaviour, a fresh seeded roll per point. A named
	# colour uses gain_bonus_energy, the same call every "gain 1 Blue" skill makes.
	var element := BlockSchema.energy_colour_id(str(b.get("colour", "")))
	for i in range(n):
		if element < 0:
			user.gain_random_energy()
		else:
			user.gain_bonus_energy(element)

func _op_cleanse(b: Dictionary) -> void:
	var only_name := str(b.get("name", ""))
	var scope := str(b.get("scope", "hostile"))
	var limit := int(b.get("count", 0))          # 0 == no limit
	for t in _block_targets(b, "user"):
		# The unqualified form must stay bit-for-bit what it has always been, so it
		# keeps calling the storage's own whole-cleanse rather than the filtered path.
		if only_name.is_empty() and limit <= 0:
			match scope:
				"own":
					t.effects.cleanse_all_ally_effects(t, user)
				"any":
					t.effects.cleanse_all_enemy_effects(t, user)
					t.effects.cleanse_all_ally_effects(t, user)
				_:
					t.effects.cleanse_all_enemy_effects(t, user)
			continue
		t.effects.cleanse_filtered(t, user, only_name, scope, limit)

# NOTE: there is no `stack` op. Stacking is EMERGENT — effect_storage.add_effect merges a
# re-application into the stored effect whenever that effect's `stackable` is true and the
# two share a name, a type and a user. `stackable` is a universal effect field, so ANY kind
# can be a stacking resource, and re-running the same `apply` block is what adds a stack.
# SPENDING one is `remove` with a `stacks` count, below.

# The mirror of `apply` — take a named effect away, or spend some of its stacks.
#
# DELIBERATELY NOT _op_cleanse. Cleanse performs the CLEANSE MECHANIC: cleanse_filtered bails
# out entirely on IGNORE_CLEANSE and skips every effect whose `cleansable` is false, because
# cleansing is something done TO an effect from outside. `remove` is the author's own
# bookkeeping — the direct remove_effect / consume_stack call shiro5 makes on its Ganta Fever
# stack and naruto1/naruto2 make on Sage Chakra Gather, and that 59 ability scripts make on
# effects they put on ENEMIES. None of them consults `cleansable`, so neither does this: a
# `cleansable` gate here would be a rule the game does not have.
func _op_remove(b: Dictionary) -> void:
	var eff_name := str(b.get("name", "")).strip_edges()
	if eff_name.is_empty():
		return
	# No `effect` = match any type carrying that name. -1 is not a member of EffectType.Type,
	# so it is safe as the "don't care" marker.
	var want_type := -1
	if b.has("effect"):
		want_type = BlockSchema.immunity_effect_id(str(b["effect"]))
		# immunity_effect_id also answers -1 for a name the enum does not have — which a
		# hand-edited file can carry, since it never met the validator. Bail rather than let it
		# collapse into the "any type" marker: an unreadable filter must remove LESS than the
		# author asked for, never more.
		if want_type < 0:
			push_warning("[blocks] remove: unknown effect type '%s' in '%s' — skipped" % [str(b["effect"]), ability.ability_name])
			return
	# 0 == the REMOVE_ALL sentinel (or an absent/garbled value): take the whole effect.
	var spend := 0
	var stacks_spec = b.get("stacks", BlockSchema.REMOVE_ALL)
	if stacks_spec is int or stacks_spec is float:
		spend = maxi(int(stacks_spec), 0)
	for t in _block_targets(b, "target"):
		_remove_matching(t, eff_name, want_type, spend)

# THE shared match. Match on effect_name(), NOT on source.ability_name (which is what
# get_all_effects_by_name reads): `name_override` is a universal authored field, so the name the
# author sees on the pip is effect_name() and that is the one they will type here.
# Collect FIRST — every teardown mutates the storage's list, and a shield break hook can add or
# remove further effects mid-loop, which is the same reason cleanse_filtered snapshots before it
# dispels. `adjust` shares this so the two ops cannot drift on what "that effect" means.
func _match_effects(t, eff_name: String, want_type: int) -> Array:
	var matches: Array = []
	for eff in t.effects._effects:
		if str(eff.effect_name()) != eff_name:
			continue
		if want_type >= 0 and int(eff.effect_type) != want_type:
			continue
		matches.append(eff)
	return matches

# Matching nothing is a NO-OP, never a warning: "spend a stack if I have one" is a legitimate
# thing to author (shiro5 guards its own spend the same way), and a warning per cast would spam
# the log for a kit that is behaving exactly as written.
func _remove_matching(t, eff_name: String, want_type: int, spend: int) -> void:
	var matches := _match_effects(t, eff_name, want_type)
	if spend > 0:
		# A spend comes off ONE instance. add_effect merges stacks on (name, type, user), so a
		# second match is a DIFFERENT caster's copy of the same-named effect, and charging the
		# author's count against each of them would spend several times what they wrote.
		if not matches.is_empty():
			_spend_stacks(t, matches[0], spend)
		return
	for eff in matches:
		_tear_down(t, eff)

# A partial spend that leaves stacks behind goes through the engine's OWN stack path,
# Effect.consume_stack (effect_component.gd:1305) — the literal call shiro5 makes. It emits
# effect_updated, which the storage has already wired to announce_change, so the pip re-renders
# without this having to know that.
func _spend_stacks(t, eff, spend: int) -> void:
	if int(eff.stacks) > spend:
		eff.consume_stack(spend)
		return
	# The count met or exceeded what was left, so the effect ENDS — exactly as consume_stack's
	# own `stacks <= 0` branch does. Spending more than remains is NOT an error; an author
	# writing "spend 2" with one stack left means "and that finishes it".
	_tear_down(t, eff)

# THE removal path. dispel_with_teardown is the engine's single-effect teardown and the only
# correct way to take an effect away by hand:
#   * SHIELD and BARRIER/Nullify go through check_effect_breaking + consume — byte-for-byte what
#     Character.shatter_shields / shatter_barrier do to one effect — so every "when my shield
#     breaks" contingency fires. Routing them here is automatic: an author who writes `remove`
#     on a shield gets that without having to know it. (`break` stays the separate "destroy ALL
#     defences" verb; it is not name-matched, and this is.)
#   * everything else ends CANCELLED, which is the ONE ending_type that runs wrapup_func.
# A bare erase_effect skips both and strands whatever depended on the effect — the documented
# trap in this codebase (Mash's protected ally stuck permanently invulnerable after her shield
# was erased instead of broken).
# It carries NONE of the cleanse mechanic: the `cleansable` gate and the IGNORE_CLEANSE bailout
# live in cleanse_all_* / cleanse_filtered, not in dispel_with_teardown, so going through it
# does not smuggle a cleanse rule into an author's own bookkeeping.
func _tear_down(t, eff) -> void:
	t.effects.dispel_with_teardown(eff, t, user)

# --- adjust: reach inside an effect already on the board ---------------------
# The read/write sibling of `remove`, sharing its addressing exactly (_match_effects). Three
# DELTA axes, any combination of which may be present:
#   turns  — the duration, in AUTHOR turns (2N ticks). "one more turn" is the single most repeated
#            comment in the corpus.
#   stacks — the stack counter, the register `stacks_at_least` reads and `apply` writes.
#   mag    — the raw magnitude: a Shield's remaining points, a DoT's per-tick damage, a damage
#            reduction's size. `tracker.mag += 1` (uzui5) and `passive.change_mag(1)` (madoka) are
#            the hand-written form.
# There is no `set` axis; see the OPS row for the abuse case that omission prevents.
func _op_adjust(b: Dictionary) -> void:
	var eff_name := str(b.get("name", "")).strip_edges()
	if eff_name.is_empty():
		return
	# Same "don't care" marker and the same fail-closed reading as _op_remove: an unreadable type
	# filter must touch FEWER effects than the author asked for, never more.
	var want_type := -1
	if b.has("effect"):
		want_type = BlockSchema.immunity_effect_id(str(b["effect"]))
		if want_type < 0:
			push_warning("[blocks] adjust: unknown effect type '%s' in '%s' — skipped" % [str(b["effect"]), ability.ability_name])
			return
	var d_turns := int(b.get("turns", 0))
	var d_stacks := int(b.get("stacks", 0))
	var d_mag := int(b.get("mag", 0))
	if d_turns == 0 and d_stacks == 0 and d_mag == 0:
		return
	for t in _block_targets(b, "target"):
		var matches := _match_effects(t, eff_name, want_type)
		if matches.is_empty():
			continue                     # nothing to adjust is a no-op, exactly as in `remove`
		# ONE INSTANCE, the same rule a partial spend follows: add_effect merges on
		# (name, type, user), so a second match is a DIFFERENT caster's copy of the same-named
		# effect and applying the author's delta to each would apply it several times over.
		_adjust_effect(t, matches[0], d_turns, d_stacks, d_mag)

# Order is mag -> stacks -> turns, and the two validity checks between them are load-bearing:
# both a stack decrement and a duration decrement can END the effect, and mutating a torn-down
# Effect raises "Invalid access ... on a previously freed object" mid-turn.
func _adjust_effect(t, eff, d_turns: int, d_stacks: int, d_mag: int) -> void:
	if d_mag != 0 and _mag_is_numeric(eff):
		var cap: int = BlockSchema.LIMITS["max_amount"]
		# change_mag rather than a bare assignment: it emits effect_updated, which storage has
		# already wired to announce_change, so the pip re-renders without this knowing that.
		# The clamp is applied around the RESULT, so a ramp cannot walk past the envelope.
		eff.change_mag(clampi(int(eff.mag) + d_mag, -cap, cap) - int(eff.mag))
	if d_stacks != 0:
		_adjust_stacks(t, eff, d_stacks)
		if not _effect_live(eff):
			return
	if d_turns != 0:
		_adjust_duration(t, eff, d_turns)

func _effect_live(eff) -> bool:
	return eff != null and is_instance_valid(eff) and not eff.removed

# `Effect.mag` IS NOT ALWAYS A NUMBER. Six shipped factories overload that register with something
# else — reflect_effect stores a live Character in it, ability_swap_effect a Vector2,
# ignore_effect_effect an EffectType int (numeric, but not a magnitude), and portrait/copy/disguise
# store their own things. `adjust` addresses an effect BY NAME, so an author can legitimately aim
# one at any of them without knowing that, and `int(eff.mag)` on a Character raises "Invalid call.
# Nonexistent 'int' constructor." — log-and-continue, so the turn survives, but the skill errored on
# EVERY cast and the delta was never applied. TYPE, not coercion: there is no number to change here,
# so the mag axis is skipped and the block's other axes (stacks, turns) still run.
#
# The KIND-level rule (BlockSchema's `reserves`) cannot cover this: it stops an author writing `mag`
# on a reflect they are BUILDING, and this is an author reaching for a reflect somebody else built.
func _mag_is_numeric(eff) -> bool:
	if eff.mag is int or eff.mag is float:
		return true
	push_warning("[blocks] adjust: '%s' keeps something other than a magnitude in its mag register (%s) in '%s' — the mag change is skipped" % [str(eff.effect_name()), type_string(typeof(eff.mag)), ability.ability_name])
	return false

# DOWN goes through _spend_stacks — the very path `remove` spends through, so "take 2 stacks" and
# "adjust -2 stacks" cannot end an effect differently. UP is a plain write, because the engine has
# no "gain a stack" call at all (12 shipped abilities do a bare `stacks += 1`).
func _adjust_stacks(t, eff, delta: int) -> void:
	if delta < 0:
		_spend_stacks(t, eff, -delta)
		return
	var want: int = mini(int(eff.stacks) + delta, _stack_cap(eff))
	if want == int(eff.stacks):
		return
	eff.stacks = want
	eff.effect_updated.emit(eff)

# NOT _stack_ceiling. That one answers 1 for an effect with no `block_max_stacks` key, which is
# correct where it is used (the mark-apply clamp, where the key is always written a line earlier)
# and would be a disaster here: it would pin every non-mark stack at 1 and make an `adjust` on a
# stacking Shield silently destroy the stack. An effect that never declared a ceiling is bounded
# by the palette's own max_stacks and nothing tighter.
func _stack_cap(eff) -> int:
	if eff.storage is Dictionary and eff.storage.has("block_max_stacks"):
		return int(eff.storage["block_max_stacks"])
	return BlockSchema.LIMITS["max_stacks"]

# `duration += 2` per author turn, plus the two edges the hand-written idiom never has to think
# about because it is written for one known effect:
#   * a PERMANENT effect (duration -1) is left alone. Adding ticks to -1 produces a small positive
#     number, so "extend it" would silently convert "forever" into "one turn" — the opposite of
#     what the author wrote, and unrecoverable.
#   * a delta that would take the duration to 0 or below ENDS the effect through the ordinary
#     teardown, rather than wrapping into the negative (where -1 means permanent again). Same
#     reading as _spend_stacks: shortening by more than is left means "and that finishes it".
func _adjust_duration(t, eff, d_turns: int) -> void:
	if int(eff.duration) < 0:
		return
	var want: int = int(eff.duration) + BlockSchema.turns_to_delta(d_turns)
	if want <= 0:
		_tear_down(t, eff)
		return
	eff.duration = want
	eff.effect_updated.emit(eff)

# --- banish -----------------------------------------------------------------
# Funnels into Character.banish_character, the ONLY writer of the `character.banished` bool that
# the win check, the tick pass, every targeting helper and _alive all read.
#
# THE ≤1 RULE IS ENFORCED HERE AS WELL AS IN THE VALIDATOR, and it is not belt-and-braces: the
# validator refuses pool selectors and refuses `to: "target"` on an AoE-targeted skill, but a
# hand-edited file on disk never met the validator, and `target` inside a payload falls back to the
# APPLIER'S STALE TARGETER when the tripping character is gone — which on an AoE cast is a whole
# team. check_win_condition counts `banished` as eliminated and check_match_over runs after every
# executed step, so a multi-target banish ends the match mid-turn. Refusing outright (rather than
# banishing the first one) is the fail-closed half: a skill that does nothing is recoverable, a
# match that ended on a technicality is not.
func _op_banish(b: Dictionary) -> void:
	var targets := _block_targets(b, "target")
	if targets.size() > 1:
		push_warning("[blocks] banish in '%s' resolved %d targets — banish may only take one; skipped" % [ability.ability_name, targets.size()])
		return
	# Raw engine ticks, 2N like every other duration: itachi2 passes 2 for "1 turn".
	var dur := BlockSchema.turns_to_duration(int(b.get("turns", 1)))
	for t in targets:
		# `user` is the banisher (banish_character branches on its own team to pick the hostile or
		# allied application path) and `ability` is the effect source, exactly as itachi2 spells it.
		var landed = user.banish_character(_ctx(), t, ability, dur)
		# THE CHANNEL ACCUMULATOR, collected here rather than in _op_apply — which is the whole bug.
		# The accumulator only ever saw _op_apply's effects, so a channelled skill whose ONLY block
		# was a banish handed _close_channel an empty list, it returned early, and NO HOLDER WAS
		# PLANTED: the card said "Channeled — everything this skill applies ends if the user is
		# stunned" and nothing ever ended.
		#
		# COLLECTED, NOT REJECTED. Refusing `channel` + `banish` would be a restriction the game does
		# not have (the hand-written channels are free to banish), and this is a two-line fix to the
		# thing that was actually missing. Ending the BANISH effect early is coherent with the engine
		# rather than novel: a channel break calls end_effect() on it, and battle_manager.tick_durations
		# clears `character.banished` on the next pass precisely when no BANISH effect is left — the
		# same mechanism an ordinary banish EXPIRY already uses, so the character returns to the board
		# by the same route, one tick later.
		#
		# A null (shrugged off, or the application refused) is not appended: _close_channel's validity
		# filter would drop it anyway, but a holder must never be planted over a banish that never was.
		if not _channel_mode.is_empty() and landed != null:
			_channel_effects.append(landed)

func _op_break(b: Dictionary) -> void:
	var what := str(b.get("what", "shield"))
	for t in _block_targets(b, "target"):
		# shatter_* rather than a bare removal: they run check_effect_breaking, which
		# is what fires every "when my shield is broken" contingency in the corpus.
		if what == "shield" or what == "both":
			t.shatter_shields(user)
		if what == "barrier" or what == "both":
			t.shatter_barrier(user)

# INSTANT KILL. Straight through the engine (instant_kill / execute_attempt) so the two shipped
# immunities — the "Embrace Pain" mark and a "Sealed Nightmare" IGNORE_DAMAGE effect — are honoured
# for free: instant_kill returns early under either, and execute_attempt calls instant_kill.
func _op_execute(b: Dictionary) -> void:
	# hp_below is a PER-TARGET threshold, not a block guard: on an AoE, testing each target itself is
	# the difference between "finish the wounded" and "wipe the team the moment one is low".
	var thresholded: bool = b.has("hp_below")
	var threshold := int(b.get("hp_below", 0))
	for t in _block_targets(b, "target"):
		if thresholded:
			# execute_attempt kills at hp <= threshold; the author's "below N" is hp <= N-1.
			t.execute_attempt(threshold - 1, user, ability)
		else:
			t.instant_kill(user, ability)

# REVIVE a dead ally — the jeanne4 idiom (abilities/jeanne4.gd:19-22). Its targets must KEEP the dead,
# which _resolve_targets / _resolve_pool drop everywhere except the dead_allies pool, so the string
# "target" is resolved here directly off the targeter (the dead ally Layer-1 include_dead flagged in).
func _op_revive(b: Dictionary) -> void:
	var amount := _amount(b.get("amount", 0))
	if amount <= 0:
		# A 0-HP revive is instantly dead again; the validator floors it at 1, this backstops an edit.
		return
	for t in _revive_targets(b.get("to", "target")):
		if t != null and is_instance_valid(t) and t.dead and not t.banished:
			t.dead = false
			t.health.set_health(amount)
			t.update.emit()

# The one target resolution that keeps the dead. A selector OBJECT routes through the normal path,
# where the dead_allies pool is the branch that skips _alive; the string "target" reads the targeter
# (or a payload's explicit targets) itself, keeping dead, non-banished characters — reviving a living
# one is a harmless no-op the caller already guards.
func _revive_targets(to) -> Array:
	if to is Dictionary:
		return _resolve_selector_object(to)
	if str(to) == "target":
		var out: Array = []
		var src = _explicit_targets if _explicit_targets != null else user.targeter.targets
		for t in src:
			if t != null and is_instance_valid(t) and not t.banished:
				out.append(t)
		return out
	return _resolve_targets(to)

# DIRECT COOLDOWN CONTROL. Matched BY NAME on each selected character's base_abilities (a copied or
# stolen skill runs from a caster whose slot order differs — abilities/stark1.gd's index failure).
func _op_cooldown(b: Dictionary) -> void:
	var delta := _signed_amount(b.get("amount", 0))
	if delta == 0:
		return
	var names := _string_list(b.get("skills", []))
	for ch in _block_targets(b, "user"):
		if ch == null or not is_instance_valid(ch) or ch.moveset == null:
			continue
		for ab in ch.moveset.base_abilities:
			if ab == null:
				continue
			if not names.is_empty() and not ab.ability_name in names:
				continue
			# THE SELF-RESET BACKSTOP (defence in depth; the validator refuses this shape too). Reducing
			# THIS ability's own cooldown on the user lands after start_cooldown()'s write and would be an
			# infinite cast — see BlockSchema.OPS' cooldown row. The validator can be skipped by a
			# hand-edited file on disk; this cannot.
			if delta < 0 and ch == user and ab == ability:
				continue
			ab.cooldown_remaining = maxi(0, int(ab.cooldown_remaining) + delta)

# DRAIN (and optionally STEAL) TEAM ENERGY. Energy is a team pool, so the drained targets are deduped
# to their distinct TEAMS, and a steal grants only the energy ACTUALLY removed — lose_energy pays what
# the pool holds and charges the rest against the team's next generation (a denial with no cleanse).
func _op_drain_energy(b: Dictionary) -> void:
	var amount := clampi(int(b.get("amount", 1)), 0, BlockSchema.LIMITS["max_energy_gain"])
	if amount <= 0:
		return
	var steal: bool = bool(b.get("steal", false))
	var teams: Array = []
	for t in _block_targets(b, "target"):
		if t == null or not is_instance_valid(t):
			continue
		var team = t.team
		if team != null and team.energy != null and not team in teams:
			teams.append(team)
	var removed := 0
	for team in teams:
		var before := _team_energy_cash(team)
		team.lose_energy(amount, battle)
		removed += maxi(0, before - _team_energy_cash(team))
	# The steal grants exactly the cash taken across every drained team — never the nominal amount,
	# which an empty or near-empty pool never actually surrendered.
	if steal:
		for _i in range(removed):
			user.gain_random_energy()

# Raw cash in a team's pool (the four real colours), the number lose_energy actually decrements. NOT
# total_available(), which subtracts promised energy — 0 during resolution, but a raw sum cannot drift.
func _team_energy_cash(team) -> int:
	var n := 0
	for key in team.energy.pool:
		n += int(team.energy.pool[key])
	return n

# SKILL SEAL — a MARK carrying skill_seal, exactly the Esdeath/Yugi idiom (abilities/esdeath2.gd:25-29),
# but with the three filter lists Ability.is_sealed_out reads exposed as authored vocabulary:
#   classes        -> class_targets    (seal skills of these classes)
#   skills         -> ability_targets  (seal these skills by name)
#   exclude_skills -> exclusion_targets (names exempted; beats every filter)
# All three empty is the "seal everything" form. Applied through add_hostile_effect (self-gating, like
# `apply`), so `bypassing` is the add_*_effect param, not a REVALIDATED_OPS pool re-check.
func _op_seal(b: Dictionary) -> void:
	var targets := _block_targets(b, "target")
	if targets.is_empty():
		return
	var dur := BlockSchema.turns_to_duration(int(b.get("turns", 1)))
	var classes := _string_list(b.get("classes", []))
	var skills := _string_list(b.get("skills", []))
	var exclude := _string_list(b.get("exclude_skills", []))
	var bypassing := bool(b.get("bypassing", false))
	for t in targets:
		var seal = Effect.mark(dur, "This character cannot use skills (sealed).")
		seal.skill_seal = true
		seal.class_targets = classes.duplicate()
		seal.ability_targets = skills.duplicate()
		seal.exclusion_targets = exclude.duplicate()
		seal.set_source(ability)
		if user.is_hostile(t):
			Character.add_hostile_effect(_ctx(), user, t, seal, bypassing)
		else:
			Character.add_allied_effect(_ctx(), user, t, seal, bypassing)

func _op_apply(b: Dictionary) -> void:
	var spec = b.get("effect", null)
	if not spec is Dictionary:
		return
	var targets := _block_targets(b, "target")
	if targets.is_empty():
		return
	var hostile := _is_hostile_effect(spec)
	# The `bypassing` PARAMETER of add_*_effect (ignore the target's invulnerability
	# for this application) — not the "Bypassing" ability class, which is a targeting
	# property and is declared on the ability, not on one block. It is also NOT the
	# universal effect field of the same name, which lives inside `effect` and means
	# "keep ticking through invulnerability" (battle_manager.gd:1229).
	var bypassing := bool(b.get("bypassing", false))
	for t in targets:
		var eff = _build_effect(spec)
		if eff == null:
			return
		# AFTER the factory, BEFORE the application: the factory owns its own arguments,
		# and add_effect reads effect_name() (hence name_override) and `stackable` the
		# moment the effect lands.
		_apply_universal_fields(eff, spec)
		# WRITE BEFORE READ (roadmap Phase E, "order matters on stacks"). A stackable effect needs its
		# ceiling recorded in `block_max_stacks` or _stack_ceiling answers the DEFAULT of 1 and the
		# generalized _clamp_stacks below pins it there — so its stacks could never be read (or grow)
		# above one. A mark already wrote it in _build_effect from its authored `max`; every OTHER
		# stackable kind has no `max` field, so it rides at the palette ceiling (max_stacks), the same
		# fallback _stack_cap uses for `adjust`. `stackable` is a universal field, so this must run
		# AFTER _apply_universal_fields set it.
		if bool(eff.stackable) and eff.storage is Dictionary and not eff.storage.has("block_max_stacks"):
			eff.storage["block_max_stacks"] = BlockSchema.LIMITS["max_stacks"]
		eff.set_source(ability)
		# NOTE: no recurring hostile-placement clamp. A permanent/over-long ticker planted on an enemy is
		# author-controlled like every effect duration — the invented RECURRING_HOSTILE_MAX_TURNS cap (and
		# this runtime backstop) were removed per the owner ruling. A hostile placement still routes through
		# add_hostile_effect below, so it passes the same gating any attack does.
		if hostile and user.is_hostile(t):
			Character.add_hostile_effect(_ctx(), user, t, eff, bypassing)
		else:
			Character.add_allied_effect(_ctx(), user, t, eff, bypassing)
		# THE MANUAL FIRST INSTANCE for `recurring` + `first: now`. The tick set is frozen before this
		# turn's abilities run (battle_manager:1622), so a ticker planted here cannot appear in this
		# turn's batch — `now` supplies the cast-turn instance by hand, exactly as fern3/stark3 do,
		# and re-uses execute_ticking_effect so it honours the same four gates a real tick does
		# (holder dead/banished, Action+stun, isolate for friendly, invuln-unless-bypassing for
		# hostile). Guarded on the effect still being live: a refused application already freed it.
		if BlockSchema.canonical_kind(spec.get("kind", "")) == "recurring" \
				and str(spec.get("first", "next")) == "now" \
				and is_instance_valid(eff) and not eff.is_queued_for_deletion() \
				and battle != null and is_instance_valid(battle):
			battle.execute_ticking_effect(eff)
		# AFTER the application, so a refusal has already queue_free'd the node and
		# _close_channel's validity filter can see it. The list mirrors what actually landed.
		if not _channel_mode.is_empty():
			_channel_effects.append(eff)
		# Enforce the ceiling on ANY stackable effect, not just marks: effect_storage's merge does a
		# bare `stacks += n` that cannot see a ceiling, so a re-applied stacking Shield/DoT would
		# breach block_max_stacks without this. The write a few lines up is what keeps a non-mark
		# effect from pinning at the _stack_ceiling default of 1. Passing the built effect (not a bare
		# name) lets _clamp_stacks re-fetch the STORED copy by name+type.
		if bool(eff.stackable) and is_instance_valid(eff):
			_clamp_stacks(t, eff)

# THE shared universal-field pass. One helper for every effect kind — that is the whole
# point of the universal set: a new kind gets all of these for free and nothing here has to
# know which kind it is holding.
#
# TWO exclusions, and they are different things:
#   * a field the KIND declares as its own (`fields` in BlockSchema.EFFECT_KINDS) is the AUTHOR'S
#     control under that same name and the factory branch has already consumed it — today only
#     mark's `stacks`, which that branch clamps to the mark's authored `max`, and re-writing it
#     here would step over that ceiling;
#   * a field the kind RESERVES (`reserves`, same table) is a register the factory wrote from a
#     DIFFERENT authored field, so writing it here silently destroys that field's value. That is
#     how a universal `mag: 0` replaced a guardian reflect's destination Character with an int and
#     made the engine call check_ability_receive_triggers on it mid-turn.
# The validator refuses the second shape outright; this is the hand-edited-file half of the guard,
# and it reads the SAME table, so the two cannot disagree about what is reserved.
func _apply_universal_fields(eff, spec: Dictionary) -> void:
	var kind := BlockSchema.canonical_kind(spec.get("kind", ""))
	var own: Array = []
	if BlockSchema.EFFECT_KINDS.has(kind):
		own = BlockSchema.EFFECT_KINDS[kind]["fields"] as Array
	var reserved := BlockSchema.reserved_fields(kind)
	for k in BlockSchema.UNIVERSAL_EFFECT_FIELDS.keys():
		if not spec.has(k) or k in own:
			continue
		if reserved.has(k):
			push_warning("[blocks] '%s' is reserved on a '%s' effect (the factory writes it from '%s') — ignored in '%s'" % [str(k), kind, str(reserved[k]), ability.ability_name])
			continue
		match str(BlockSchema.UNIVERSAL_EFFECT_FIELDS[k]):
			"bool":
				eff.set(k, bool(spec[k]))
			"int":
				eff.set(k, _universal_int(k, spec[k]))
			"string":
				eff.set(k, str(spec[k]))

# Defence in depth: the validator range-checks these, but a hand-edited file never met the
# validator. The bounds are the SAME LIMITS the validator uses, so the two cannot disagree.
func _universal_int(key: String, v) -> int:
	match key:
		"stacks":
			return clampi(int(v), 1, BlockSchema.LIMITS["max_stacks"])
		"mag":
			var cap: int = BlockSchema.LIMITS["max_amount"]
			return clampi(int(v), -cap, cap)
	return int(v)

# Effect carries no max-stacks field, and effect_storage.add_effect merges a repeat
# application with a bare `eff_match.stacks += ...` that cannot know about a ceiling.
# So the ceiling rides in the effect's own generic `storage` dict (the same scratch
# space xanxus_storage uses) and is enforced here, right after the merge that could
# have breached it. Doing it at apply time — rather than adding a field to Effect —
# keeps the cap entirely inside the authored-content layer.
# `built_eff` is the effect the runner just constructed; on a STACKING re-application add_effect
# merges onto the already-present copy and discards this one, so the stored instance — not the one
# in hand — is what has to be clamped. Re-fetch it by name+TYPE+user, the same triple has_effect
# keys on, reading the type off the built effect rather than hardcoding MARK. That un-hardcode is
# the write side of what Phase B already did on the read side (stacks_at_least uses MARK as a
# _presence_type DEFAULT, not a hardcode): a stacking Shield / DoT / cost modifier is countable and
# clampable, not mark-only.
func _clamp_stacks(t, built_eff) -> void:
	if built_eff == null or not is_instance_valid(built_eff):
		return
	var eff = t.has_effect(built_eff.effect_name(), built_eff.effect_type, user)
	if eff == null:
		return
	var ceiling := _stack_ceiling(eff)
	if eff.stacks > ceiling:
		eff.stacks = ceiling
		eff.effect_updated.emit(eff)

func _stack_ceiling(eff) -> int:
	return int(eff.storage.get("block_max_stacks", 1)) if eff.storage is Dictionary else 1

# Harmful-to-the-holder effects must go through add_hostile_effect so they
# respect shrug-off / IGNORE_SKILL / application gating.
#
# A4: hostility is DATA — the per-kind `hostile` column of BlockSchema.EFFECT_KINDS — read
# generically here. The literal name list this replaced was a second palette that had to be
# edited in step with the first, and the Simple Effect Table adds ~20 kinds at once: a table
# row that forgot to appear in the runner's list would route an Isolate through
# add_allied_effect and land it on targets no hand-written kit could reach.
#
# HOSTILE_BY_SIGN covers the two kinds whose SIGN decides which side of the fence they land
# on: +1 Random to cast is a tax, -1 is a discount. The hostile path is gating meant for
# attacks — is_ignoring_skill, shrug_off_type and can_apply_hostile_effect (invulnerability)
# — and every one of those refusals ends in _free_unapplied_effect. Route a discount through
# it and an ALLY can "resist" being helped: an invulnerable teammate silently drops the buff
# you cast on them. (_op_apply also requires user.is_hostile(t), so a positive modifier aimed
# at a teammate still lands through the allied path.)
func _is_hostile_effect(spec: Dictionary) -> bool:
	var kind := BlockSchema.canonical_kind(spec.get("kind", ""))
	if not BlockSchema.EFFECT_KINDS.has(kind):
		return false               # unknown kind: _build_effect refuses it anyway
	var column = BlockSchema.EFFECT_KINDS[kind].get("hostile", null)
	if column == null:
		# Fail CLOSED. A kind added without the column is a palette bug, and the gated path is
		# the safe half of the guess: an over-gated buff can be refused, an un-gated attack
		# reaches somebody the game says it may not.
		push_warning("[blocks] effect kind '%s' declares no hostility — treated as hostile" % kind)
		return true
	if column is String:
		# A4's third answer, and now its fourth: two kinds cannot declare a fixed side because
		# ONE AUTHORED FIELD decides it. Both are read here rather than in the kind's branch of
		# _build_effect, so the routing question is answered in exactly one place.
		if str(column) == BlockSchema.HOSTILE_BY_COUNTER_SIDE:
			# An OUTGOING counter is a muzzle fitted to the bearer, so it has to pass the same
			# gating an attack does. An incoming one is a shield handed to them and must not.
			return str(spec.get("on", "incoming")) == "outgoing"
		# HOSTILE_BY_SIGN, and the two new cost modes read correctly through it without a rule of
		# their own: a `set` of 0 ("this skill is now free") is a gift and reads not-hostile, a
		# `set` of N is a re-price and reads hostile, and a `swap` carries no `amount` at all so it
		# falls to the absent default of 1 and routes hostile — the fail-closed half of the guess.
		# None of that can over-gate an ally: _op_apply only takes the hostile path when
		# user.is_hostile(t), so a self-cast transformation still lands through the allied path.
		# WHICH sign is the attack differs by kind: a cost/cooldown TAX is positive, but a
		# `damage_boost` WEAKEN is negative — SIGN_HOSTILE_WHEN_NEGATIVE flips the test for those, or
		# a negative weaken would route ALLIED and skip the invuln / shrug-off / skill-ignore gates a
		# hostile application must pass. Absent `amount` fails CLOSED to hostile on both polarities.
		if str(column) == BlockSchema.HOSTILE_BY_SIGN:
			if kind in BlockSchema.SIGN_HOSTILE_WHEN_NEGATIVE:
				return int(spec.get("amount", -1)) < 0
			return int(spec.get("amount", 1)) > 0
		return false
	return bool(column)

# --- effect construction ----------------------------------------------------
func _build_effect(spec: Dictionary):
	# canonical_kind, not the raw string: a character authored before the reactive->trigger
	# rename still says "reactive" in its saved JSON and must keep working.
	var kind := BlockSchema.canonical_kind(spec.get("kind", ""))
	var delayed := bool(spec.get("delayed", false))
	# spec_duration, not turns_to_duration: it honours a raw `ticks` when the author gave one,
	# which is the only way to reach an ODD engine duration (2N can never be odd, and the
	# roster is full of odd ones).
	var dur := BlockSchema.spec_duration(spec, delayed)
	var amount := _amount(spec.get("amount", 0))
	match kind:
		"mark":
			var mk = Effect.mark(dur, str(spec.get("text", "")))
			var ceiling := clampi(int(spec.get("max", 1)), 1, BlockSchema.LIMITS["max_stacks"])
			# Effect.mark leaves `stackable` at false, and effect_storage merges onto the ALREADY
			# STORED effect's flag — so without this a re-application replaced the mark instead of
			# stacking it and the `stacks_at_least` condition could never be satisfied. Authored marks
			# are counters by design (that is what the condition is FOR), so they stack.
			# Kept unconditional even at max 1: with stackable false, add_effect's non-refresh branch
			# _stores a second copy_ of an already-present mark, so a plain re-cast would pile up
			# duplicate marks. Stacking + a ceiling of 1 is what "re-casting refreshes it" looks like.
			mk.stackable = true
			mk.stacks = clampi(int(spec.get("stacks", 1)), 1, ceiling)
			# Showing "1" on a mark that can never reach 2 is noise, so the pip counter defaults on
			# only for a mark the author actually declared as a resource.
			mk.display_stacks = bool(spec.get("show_stacks", ceiling > 1))
			mk.storage["block_max_stacks"] = ceiling
			return mk
		"damage_over_time":
			var e = Effect.damage_effect(amount, BlockSchema.damage_type_id(str(spec.get("damage_type", "NORMAL"))), dur)
			if delayed:
				e.last_turn_only = true   # a single tick N turns from now
			return e
		"heal_over_time":
			return Effect.healing_effect(amount, dur)
		"shield":
			return Effect.shield_effect(amount, dur)
		"stun":
			return Effect.stun_effect(dur, _string_list(spec.get("classes", [])), _string_list(spec.get("exclude_classes", [])))
		"invulnerable":
			return Effect.invuln_effect(dur, _string_list(spec.get("classes", [])))
		"ignore_damage":
			return Effect.ignore_damage_effect(dur)
		"damage_reduction":
			return Effect.damage_reduction_effect(amount, dur)
		"vulnerability":
			# The two damage-type lists thread the factory's class_targets (INCLUDE) / exclusion_targets
			# (EXCLUDE) args — the SAME filter get_true_damage honours on a VULNERABILITY effect
			# (ability_component.gd:800-811), exactly like damage_boost below. The factory's 3rd arg is the
			# ability-NAME filter, which this kind deliberately does NOT expose, so it stays []. Absent
			# lists resolve to [] — the factory's own default — so an unfiltered vulnerability is byte-for-
			# byte today. `amount` is UNSIGNED (_amount above): a vulnerability is always "more damage
			# taken", never a negative, so there is no _signed_amount here as there is for damage_boost.
			return Effect.vulnerability_effect(
				amount, dur, [],
				_damage_type_list(spec.get("include_types", [])),
				_damage_type_list(spec.get("exclude_types", [])))
		"damage_boost":
			# SIGNED: _signed_amount, NOT _amount — a weaken is a NEGATIVE mag, and _amount clamps
			# 0..max (it would silently zero every weaken). Same clamp cost_change/cooldown_change use.
			# The two damage-type lists thread the factory's class_targets (INCLUDE) / exclusion_targets
			# (EXCLUDE) args, which get_true_damage compares against the hit's damage_type. Absent lists
			# resolve to [] — the factory's own default — so a plain positive boost is byte-for-byte today.
			return Effect.damage_mod_effect(
				_signed_amount(spec.get("amount", 0)), dur,
				_string_list(spec.get("skills", [])),
				_damage_type_list(spec.get("include_types", [])),
				_damage_type_list(spec.get("exclude_types", [])))
		"silence":
			return Effect.silence_effect(dur)
		"destructible_break":
			return Effect.def_negate(dur)
		"trigger":
			return _build_trigger(spec, dur)
		"recurring":
			# Its OWN duration function, not the shared `dur`: `first` folds the manual-first-instance
			# idiom into an odd 2K-1 engine duration that spec_duration cannot express.
			return _build_recurring(spec)
		"counter":
			return _build_counter(spec, dur)
		"reflect":
			return _build_reflect(spec, dur)
		"redirect":
			return _build_redirect(spec, dur)
		"swap":
			return _build_swap(spec)
		"cost_change":
			var element := BlockSchema.energy_colour_id(str(spec.get("colour", "random")))
			if element < 0:
				push_warning("[blocks] unknown cost colour '%s' in '%s'" % [str(spec.get("colour", "")), ability.ability_name])
				return null
			return _build_cost_change(spec, dur, element)
		"cooldown_change":
			return Effect.cooldown_mod(_signed_amount(spec.get("amount", 0)), dur, _string_list(spec.get("skills", [])))
		"paralyze":
			return Effect.paralyze_effect(dur)
		"taunt":
			return Effect.taunt_effect(dur, user)
		"effect_immunity":
			var etype := BlockSchema.immunity_effect_id(str(spec.get("effect", "")))
			if etype < 0:
				push_warning("[blocks] unknown immunity effect '%s' in '%s'" % [str(spec.get("effect", "")), ability.ability_name])
				return null
			return Effect.ignore_effect_effect(dur, etype)
		"portrait_change":
			# Build through the NAMED factory so the effect inherits system=true and cleansable=false
			# (effect_component.gd:575) — the generic __simple__ arm CANNOT set either. `index` is the
			# 0-based alt-portrait slot; the factory stores it in `mag` (reserved, so _apply_universal_fields
			# skips a universal mag and cannot clobber it). The validator bounds `index` to the alt-slot
			# count; this is the hand-edited-file backstop that a bad index still builds a defined effect.
			return Effect.portrait_change_effect(int(spec.get("index", 0)), dur)
	# THE PHASE C GENERIC ARM. Every Simple Effect row is built here — one call to Effect.from, no
	# named factory, no per-kind branch. It is the arm that makes "one build arm plus N data rows"
	# literally true: adding a row to BlockSchema.SIMPLE_EFFECTS reaches this without another line.
	if BlockSchema.SIMPLE_EFFECTS.has(kind):
		return _build_simple_effect(kind, spec, dur)
	push_warning("[blocks] unknown effect kind '%s' — skipped" % kind)
	return null

# The generic Simple Effect builder. Effect.from(type, {}) instantiates a bare Effect with the type
# set and EVERY callable at its no-op default (effect_component.gd:41-45) — proven safe per row in
# BlockSchema.SIMPLE_EFFECTS. This helper then does the only two things the table asks of it:
#   * set_duration — exactly what every named factory arm above does; the engine `dur` was already
#     resolved by spec_duration (honouring `ticks`), so this is the same value a factory would get.
#   * write `mag` FROM the author's `amount`, in the row's declared convention. This is why a
#     magnitude row RESERVES mag: `amount` is its single writer, and letting the universal pass write
#     mag too would silently clobber this line. "retained" is the one convention that bends the number
#     (HEAL_CUT stores % retained; the author gave % cut), every other row writes amount straight.
# It is deliberately NOT named `_build_<kind>`: the section-K factory enumerator resolves a
# `_build_<kind>` helper to that kind and folds its writes in, and a per-kind helper here would make
# it demand a reservation for `duration` on every row. One generic helper writes only mag (reserved)
# and duration (engine bookkeeping, never in the universal set), so the enumerator stays clean.
func _build_simple_effect(kind: String, spec: Dictionary, dur: int):
	var row: Dictionary = BlockSchema.SIMPLE_EFFECTS[kind]
	var eff = Effect.from(EffectType.Type[str(row["type"])], {})
	eff.set_duration(dur)
	var amount := _amount(spec.get("amount", 0))
	if "amount" in (row.get("fields", []) as Array):
		eff.mag = _simple_mag(str(row.get("mag", "flat")), amount)
	# Generated tooltip, from the READER's semantics (the table's `tip`), never a factory string. The
	# {amount} it prints is the author's number in the "bigger = stronger" convention, which is what a
	# player reads on the card — so tip and card and match all say one number (see the HEAL_CUT note).
	var tip := str(row.get("tip", "")).format({"amount": amount})
	if tip != "":
		eff.description = func desc(_e): return tip
	return eff

# The ONE mag-normalisation point (see BlockSchema.SIMPLE_EFFECTS' convention note). "retained"
# inverts an author's "percent removed / cut" into the register HEAL_CUT actually reads (percent
# retained); every other row is a straight magnitude. The 0..100 clamp is the reader's own ceiling —
# a HEAL_CUT mag below 0 would turn a heal into damage, a PERCENT_DR mag above 100 would heal the
# attacker's target — and the validator's amount_max stops the author reaching either, this is the
# hand-edited-file backstop.
func _simple_mag(convention: String, amount: int) -> int:
	match convention:
		"retained":
			return clampi(100 - amount, 0, 100)
	return amount

# THREE cost mechanics behind one kind, because they answer one authoring question ("what does
# this skill cost now?") and Ability.cost() consults all three in a fixed order. Splitting them
# into three kinds would have made an author pick the EFFECT TYPE rather than the OUTCOME.
func _build_cost_change(spec: Dictionary, dur: int, element: int):
	var skills := _string_list(spec.get("skills", []))
	match str(spec.get("mode", "add")):
		"set":
			# COST_CHANGE OVERRIDES the whole cost — cost() zeroes every colour and then writes
			# alternative_cost over it (ability_component.gd:285-307). So one colour and one amount
			# IS the complete new price, and `amount: 0` is the "this skill is free" shape (which
			# _amount's floor makes reachable and _signed_amount would not).
			var flat := _amount(spec.get("amount", 0))
			return Effect.cost_change_effect({element: flat} if flat > 0 else {}, dur, skills)
		"swap":
			# COLOR_CHANGE moves whatever the skill costs in `from` across to `colour`, leaving the
			# TOTAL unchanged. Factory argument order is (incoming, replaced): the author's `colour`
			# is what it costs now, `from` is what it used to.
			var replaced := BlockSchema.energy_colour_id(str(spec.get("from", "")))
			if replaced < 0:
				push_warning("[blocks] cost swap needs a 'from' colour in '%s' — skipped" % ability.ability_name)
				return null
			return Effect.color_change_effect(element, replaced, dur, skills)
	# "add" — COST_MOD, the historical shape. SIGNED: the shared `amount` above is clamped to >= 0,
	# which would silently turn every authored discount into a 0-magnitude no-op. The engine factory
	# already speaks both directions ("more"/"less"), so only the clamp had to change.
	return Effect.cost_mod_effect(_signed_amount(spec.get("amount", 0)), dur, element, skills)

# Replaces one of the author's own visible slots with another of their own skills.
func _build_swap(spec: Dictionary):
	var kit = user.moveset.base_abilities
	var into := int(spec.get("into", -1))
	var slot := int(spec.get("slot", -1))
	if into < 0 or into >= kit.size() or slot < 0 or slot >= kit.size():
		push_warning("[blocks] swap slot/into out of range in '%s' — skipped" % ability.ability_name)
		return null
	# A swap's "N turns" is 2N+1, NOT the 2N every other effect uses: it is applied on
	# the caster's own turn and eats a tick immediately, so 2N would expire it one turn
	# early. Both shipped swaps (gasai2, yoruichi3) pass 7 for "3 turns".
	# apply_effect DROPS an ABILITY_SWAP whose source is not in the applier's
	# base_abilities; _op_apply's set_source(ability) is what satisfies that.
	return Effect.ability_swap_effect(into, slot, user, BlockSchema.spec_swap_duration(spec))

# A counter INTERCEPTS: Character.countered() consults these before the incoming
# skill resolves, and the skill is cancelled outright. That makes it a different
# animal from `trigger`, which merely watches an event that already happened.
func _build_counter(spec: Dictionary, dur: int):
	var then_blocks = spec.get("then", [])
	var owner_ability = ability
	var scope = spec.get("scope", "harmful")
	# A shortcut name OR a literal class list — counter_effect's class_targets is a free
	# list, which is how korra1 watches only ["Affliction"]. counter_classes duplicates,
	# because a const Dictionary's nested arrays are read-only and this is handed straight
	# to the effect.
	var classes: Array = BlockSchema.counter_classes(scope)
	# `exclude` SUBTRACTS from that inclusion set: a skill scope matched but that ALSO carries an
	# excluded class is let through (Condition.action_countered returns false on any exclusion hit).
	# It resolves through the SAME counter_classes() path as scope, and ABSENT resolves to [] — the
	# empty default counter_classes([]) returns — so the no-exclude call below is byte-for-byte the
	# hardcoded [] it replaces. This is what makes saitama4's "Harmful except Strategic" expressible.
	var exclude_classes: Array = BlockSchema.counter_classes(spec.get("exclude", []))
	var payload := func(context):
		var eff = context.get("effect")
		var applier = eff.user if eff != null else null
		if applier != null and is_instance_valid(applier):
			var runner := BlockRunner.new(owner_ability, applier.battle, applier)
			# "target" inside the payload means whoever walked into the counter.
			var tripped = context.get("owner")
			if tripped != null and is_instance_valid(tripped):
				runner.set_explicit_targets([tripped])
			# Same addressing a trigger payload gets. QueryContext.from_counter_check passes the
			# counter's bearer as `target` on the COUNTER_RECEIVE path
			# (scripts/character_component.gd:441-443), so `holder` and `affected` agree here —
			# but they are still worth having: `user` is the APPLIER, and a counter planted on an
			# ally by someone else is exactly the case where the applier is not the defender.
			runner.set_payload_addressing(eff.target, context.get("target"))
			runner.run(then_blocks)
		# Load-bearing, not bookkeeping: default_counter_trigger is what posts the
		# counter notification and spends the effect. A counter that skips it leaves
		# the cancel half-done — mercury3 is the shipped shape being reproduced here.
		owner_ability.default_counter_trigger(context)
	# WHICH SIDE. COUNTER_RECEIVE (incoming) is read off the ATTACKER'S TARGETS in countered()'s
	# second loop; COUNTER_USE (outgoing) is read off the acting character in its first, so an
	# outgoing counter eats the bearer's OWN next skill. Both are cancelled by the same line —
	# `if not char.countered(self, ability)` in "new multiplayer/battle_manager.gd":1204 — which is
	# the live path and the only one. (check_counter_use_effects / check_counter_receive_effects
	# have zero callers repo-wide; wiring to them would look right and do nothing.)
	var side := BlockSchema.counter_side_id(spec.get("on", "incoming"))
	# The exclusion tail hangs off "skill" — "" when nothing is subtracted, so a counter with no
	# `exclude` prints exactly today's sentence.
	var excl := _except_word(spec.get("exclude", []))
	var desc := ""
	if side == EffectType.Type.COUNTER_USE:
		desc = "The next %sskill%s this character uses will be countered." % [_scope_word(scope), excl]
	else:
		desc = "The next %sskill%s used on this character will be countered." % [_scope_word(scope), excl]
	var eff = Effect.counter_effect(Trigger.always(payload), side, dur, desc, classes, exclude_classes)
	# Without a timeout an unspent counter vanishes silently; every shipped counter
	# posts the expiry notice through this same default.
	eff.wrapup_func = owner_ability.default_counter_timeout
	return eff

# A reflect RE-AIMS the incoming skill instead of cancelling it. Character.reflect_check
# (scripts/character_component.gd:385-416) consults these in the same pass, under the same
# Uncounterable / IGNORE_COUNTER / stealth rules, immediately after countered() has declined.
#
# THE TRIGGER IS THE ENGINE'S OWN, and that is the whole design: Ability.reflect_trigger
# (abilities/scripts/ability_component.gd:374) already solves both re-aim traps —
#   * a common AoE is TargetType.ALL, not ALL_FACTION, so the multi-target branch has to be
#     reached by ruling out SINGLE rather than by testing for ALL_FACTION;
#   * a bounced AoE's new pool must be re-validated against extra_targetable AND bypass-aware
#     invulnerability (reflect_retarget_to_team, :418-433), so an untargetable teammate is spared
#     exactly as a normal harmful AoE would spare an enemy.
# Rebuilding either as authored blocks would be a second copy of the trickiest part of targeting,
# and it is the copy that would drift. So this function only chooses the two things an author
# actually decides: WHERE it goes and HOW MANY it eats.
func _build_reflect(spec: Dictionary, dur: int):
	var classes: Array = BlockSchema.counter_classes(spec.get("scope", "harmful"))
	# Same subtraction `counter` carries, same resolution path, same byte-for-byte-when-absent rule:
	# reflect stores exclusion_targets and action_countered reads it on the reflect check too, so
	# "reflect Harmful except Strategic" is buildable. Absent => [] => the hardcoded [] this replaces.
	var exclude_classes: Array = BlockSchema.counter_classes(spec.get("exclude", []))
	# `mag` is the destination the engine reads. -1 is the sentinel for "back at whoever used it";
	# anything else is the Character it lands on instead. The AUTHOR names a ROLE, never a
	# character — that is what keeps a live Node out of authored data — and `user` here is the
	# caster, computed at build time exactly as eren2/mash4/saber3/tamaki4/kitara2 pass their own.
	var dest := str(spec.get("destination", "attacker"))
	var mag = user if dest == "applier" else BlockSchema.REFLECT_UNLIMITED
	# `stacks` is the CHARGE register, and the engine reads it as a two-state: reflect_trigger
	# consumes the whole effect unless it is exactly -1. Anything the validator let through is
	# therefore -1 (lasts its whole duration) or 1 (the next skill only).
	var charges := int(spec.get("charges", BlockSchema.REFLECT_UNLIMITED))
	# The in-battle tooltip. The scope word sits in front of "skill", so "any" (which resolves to an
	# empty class list and filters nothing) has to become no word at all rather than the literal
	# "any skill", which reads as a filter that is not there — _scope_word answers "" for it, so the
	# `== "any"` special case this line used to carry is gone.
	var scope_word := _scope_word(spec.get("scope", "harmful"))
	# The exclusion tail hangs off "skill(s)" — "" when nothing is subtracted, so a reflect with no
	# `exclude` prints exactly today's sentence.
	var excl := _except_word(spec.get("exclude", []))
	var where := "back at its user" if dest == "attacker" else "onto this effect's caster"
	var desc := ""
	if charges == BlockSchema.REFLECT_UNLIMITED:
		desc = "%sskills%s used on this character will be reflected %s." % [scope_word, excl, where]
	else:
		desc = "The next %sskill%s used on this character will be reflected %s." % [scope_word, excl, where]
	return Effect.reflect_effect(Trigger.always(ability.reflect_trigger), EffectType.Type.REFLECT_RECEIVE, mag, dur, desc, classes, exclude_classes, charges)

# A redirect MOVES `amount`% of every hit the holder takes to a character a SELECTOR chooses — the
# damage-layer sibling of reflect. The whole authoring decision is two things: how much of the hit
# moves, and (via the selector) where it goes.
#
# THE DESTINATION IS RESOLVED AT REDIRECT TIME, NOT NOW. reflect can bake its destination at build
# time because its two roles ("attacker"/"applier") are known then; a redirect's destination is a
# free Phase F selector ("a random living ally", "the lowest-HP ally"), and the answer changes hit to
# hit as characters die. So instead of a Character we hand the effect a RESOLVER closure that, each
# time a hit lands, builds a fresh runner from the effect's own live applier/battle and re-runs the
# selector — exactly how _build_trigger's payload rebuilds a runner per fire. It returns AT MOST one
# character (the first the selector yields) or null, and Character.check_damage_redirect makes a null
# / dead / banished answer no-op the redirect (the hit lands normally) rather than black-hole it.
func _build_redirect(spec: Dictionary, dur: int):
	# `amount` is the PERCENTAGE moved; mag is the fraction the engine multiplies each hit by. Clamped
	# to [0,1]: above 100% the redirect would deal the absorber MORE than the hit and drive the holder's
	# incoming damage negative (a heal) — the same reader-maths inversion percent_dr guards at 100. The
	# validator rejects >100 with a message; this is the hand-edited-file backstop.
	var amount := _amount(spec.get("amount", 0))
	var mag: float = clampf(float(amount) / 100.0, 0.0, 1.0)
	var selector = spec.get("destination", {"pool": "other_allies", "pick": "random", "count": 1})
	var owner_ability = ability
	# THE RESOLVER — run by check_damage_redirect, not now. STATIC-safe like _scope_matches's siblings:
	# it captures only plain locals (owner_ability, selector) and reads everything else off the effect
	# it is handed, so it does not outlive-capture this RefCounted runner.
	var resolver := func(eff):
		var applier = eff.user
		if applier == null or not is_instance_valid(applier):
			return null
		var b = applier.battle
		if b == null or not is_instance_valid(b):
			return null
		var r := BlockRunner.new(owner_ability, b, applier)
		# The protected character (the effect's holder) is addressable as "target"/"holder" inside the
		# selector, so a `where` can reference or exclude it — bound exactly as a trigger payload binds
		# the character that tripped it.
		var holder = eff.target
		if holder != null and is_instance_valid(holder):
			r.set_explicit_targets([holder])
			r.set_payload_addressing(holder, holder)
		var picks: Array = r.resolve_selection(selector)
		# FIRST resolved, dead or alive: the dead/absent decision belongs to check_damage_redirect (the
		# single point the ruling names), so a `dead_allies` selector hands it a real corpse to reject
		# rather than being silently filtered here. Living pools already dropped the dead upstream.
		return picks[0] if not picks.is_empty() else null
	return Effect.redirect_selector_effect(mag, resolver, dur, _redirect_desc(spec, mag))

# The in-battle tooltip. The generated ability CARD (ScriptedAbility._describe_effect) is the real
# contract; this is only what a player sees hovering the effect chip mid-match, so it names the
# fraction and the destination in plain words.
func _redirect_desc(spec: Dictionary, mag: float) -> String:
	return "%d%% of the damage this character takes is redirected to %s." % [int(round(mag * 100.0)), _destination_words(spec.get("destination", {}))]

# A short phrase for a redirect's destination selector ("a random ally", "the lowest-HP ally", ...).
# Deliberately small: the exact pool/where semantics live on the generated card; this is a tooltip.
func _destination_words(sel) -> String:
	if not sel is Dictionary:
		return "another character"
	var pool := str(sel.get("pool", "other_allies"))
	var noun: String = {
		"allies": "an ally", "other_allies": "another ally", "enemies": "an enemy",
		"everyone": "another character", "user": "itself", "target": "the target",
		"main_target": "the primary target", "other_targets": "another target", "dead_allies": "a fallen ally",
	}.get(pool, "another character")
	match str(sel.get("pick", "all")):
		"random":  return "a random %s" % _bare_noun(noun)
		"lowest":  return "the lowest-%s %s" % [str(sel.get("measure", "hp")), _bare_noun(noun)]
		"highest": return "the highest-%s %s" % [str(sel.get("measure", "hp")), _bare_noun(noun)]
	return noun

# Strip a leading article so "an ally" composes into "a random ally" / "the lowest-hp ally".
func _bare_noun(noun: String) -> String:
	for a in ["another ", "an ", "a ", "the "]:
		if noun.begins_with(a):
			return noun.substr(a.length())
	return noun

# PUBLIC: resolve a DESTINATION selector to a live character list, for an engine hook that runs
# OUTSIDE a cast (Character.check_damage_redirect, via the redirect resolver closure on a fresh
# runner). A Dictionary is a Phase F selector object (pool x where x pick x order); a String is a
# plain selector, resolved with no per-candidate filter and no re-validation gate — the same defaults
# a top-level block `to` gets. Kept public because it is the one selector entry point the engine calls.
func resolve_selection(sel) -> Array:
	if sel is Dictionary:
		return _resolve_selector_object(sel)
	return _resolve_targets(sel, null, null)

# A trigger effect's payload is ITSELF a block list. This is what lets authored
# content express the engine's 277 trigger_effect sites as pure data: we bind a
# Callable that, when the hook fires, runs the `then` blocks with the effect's
# owner as the acting user and the triggering character as the target.
func _build_trigger(spec: Dictionary, dur: int):
	var trig_id := BlockSchema.trigger_hook_id(str(spec.get("trigger", "")))
	if trig_id < 0:
		push_warning("[blocks] unknown trigger '%s'" % str(spec.get("trigger", "")))
		return null
	var then_blocks = spec.get("then", [])
	var owner_ability = ability
	# THE EVENT-CLASS FILTER. Absent means "every occurrence of this hook", which is what every
	# authored trigger did before the field existed — so an existing saved character is untouched.
	# Present means the skill that fired the hook must carry one of these classes. The vocabulary
	# is COUNTER_SCOPES verbatim (shortcut name or a raw class list), and an empty resolved list
	# ("any") matches everything, exactly as Condition.action_countered reads an empty
	# class_targets. The validator rejects the field on the four hooks that carry no skill.
	var scoped := spec.has("scope")
	var scope_classes: Array = BlockSchema.counter_classes(spec.get("scope")) if scoped else []
	# RE-ENTRANCY LATCH — the reason this is here and not left to the engine:
	# the dispatchers guard themselves with `if eff.triggered: continue`, and NOTHING in the
	# engine ever sets that flag. Three hand-written kits set it inside their own payload by hand
	# (frieza2.gd:102, frieza3.gd:49, machinedramon3.gd:47) — an author has no way to write that
	# line, so authored content needs the equivalent built in.
	# Without it a payload that moves the holder's HP re-enters its own hook: on_hp_changed fires
	# from receive_damage (:531) and receive_healing (:1112), and receive_healing calls it
	# UNCONDITIONALLY — even for a heal the max-HP clamp reduced to zero. So "when my health
	# changes, heal me" on a full-HP holder recurses with no terminator at all and takes the match
	# down with it. Damage self-terminates only because the holder eventually dies.
	# The latch is per EFFECT INSTANCE (one closure per _build_effect call), so two copies of the
	# same authored trigger on two characters do not gate each other.
	var running := [false]
	var payload := func(context):
		if scoped and not BlockRunner._scope_matches(scope_classes, context.get("source")):
			return
		if running[0]:
			return
		var eff = context.get("effect")
		# The acting user stays the effect's APPLIER, unchanged: it is who the damage and healing
		# are attributed to, and who `user` has always meant inside a payload. The BEARER is now
		# reachable as `holder` instead of being unaddressable.
		var applier = eff.user if eff != null else null
		if applier == null or not is_instance_valid(applier):
			return
		running[0] = true
		var runner := BlockRunner.new(owner_ability, applier.battle, applier)
		# The trigger's "target" selector means whoever tripped it.
		var tripped = context.get("owner")
		if tripped != null and is_instance_valid(tripped):
			runner.set_explicit_targets([tripped])
		# context.value is the event magnitude on the damage/healing hooks (damage received/dealt,
		# healing given) and null on the rest — passed through so the `event` reading can reflect it.
		runner.set_payload_addressing(eff.target, context.get("target"), context.get("value"))
		runner.run(then_blocks)
		running[0] = false
	return Effect.trigger_effect(Trigger.always(payload), trig_id, dur, str(spec.get("text", "")))

# A `recurring` is a TICKING_TRIGGER whose payload is a nested block list — the sibling of
# _build_trigger, but wired to the ticking dispatcher rather than a hook. execute_ticking_effect
# ("new multiplayer/battle_manager.gd":1255-1263) fires this effect's trigger once every AUTHOR'S
# turn (the tick set is scoped by the effect's USER's side, so an enemy-planted ticker fires on the
# CASTER's turn — the engine's own side-scoping, honoured here rather than reimplemented).
#
# NO re-entrancy latch, unlike _build_trigger: a ticking trigger fires from the once-per-turn tick
# loop, not from inside receive_damage/receive_healing, so a payload that moves the holder's HP
# cannot re-enter its own hook the way an on_hp_changed trigger could.
#
# THE ADDRESSING is fixed, not event-driven: a tick has no "character who tripped it", so `holder`,
# `affected` and a bare `target` all resolve to the character CARRYING the effect (eff.target). That
# is what makes the corpus's own shape — "each turn, deal N to the enemy this sits on" — the plain
# `{"op":"damage","to":"holder"}` (or the default `to`).
func _build_recurring(spec: Dictionary):
	var then_blocks = spec.get("then", [])
	var owner_ability = ability
	var payload := func(context):
		var eff = context.get("effect")
		if eff == null:
			return
		# The acting user is the effect's APPLIER, exactly as a trigger payload: it is who the
		# damage and healing are attributed to. The BEARER is the effect's target.
		var applier = eff.user
		if applier == null or not is_instance_valid(applier):
			return
		var holder = eff.target
		var runner := BlockRunner.new(owner_ability, applier.battle, applier)
		if holder != null and is_instance_valid(holder):
			runner.set_explicit_targets([holder])
		# holder AND affected both address the bearer: a tick is not a reaction to somebody else's
		# action, so there is no separate patient.
		runner.set_payload_addressing(holder, holder)
		runner.run(then_blocks)
	# Description left to the effect name (the ability's), the same as an unlabelled _build_trigger:
	# the ability CARD's prose is generated by ScriptedAbility._describe_effect and is the contract.
	return Effect.trigger_effect(Trigger.always(payload), EffectType.Type.TICKING_TRIGGER, BlockSchema.recurring_duration(spec), "")

# Does the skill that fired this hook carry one of the scope's classes?
#
# STATIC on purpose: the payload closure must not capture `self`. The BlockRunner that BUILT the
# effect is a RefCounted belonging to a cast that finished turns ago, and every other value the
# closure needs is already captured as a plain local (owner_ability, then_blocks).
static func _scope_matches(classes: Array, src) -> bool:
	if classes.is_empty():
		return true                     # "any" — the filter is present but names nothing
	var ab = _scope_ability(src)
	if ab == null:
		return false                    # no skill to read a class off: a filtered trigger stays silent
	for c in classes:
		if bool(ab.classes.get(str(c), false)):
			return true
	return false

# The Ability behind a hook's source. On the use/receive hooks the dispatcher hands us the Ability
# directly; on the damage hooks the source can be an EFFECT (a DoT tick), and the engine's own
# attribution unwraps that to the effect's SOURCE ability — receive_healing does exactly this when
# matching HEALING_RECEIVED_MOD.ability_targets (scripts/character_component.gd:1085-1087).
static func _scope_ability(src):
	if src is Ability:
		return src
	if src is Effect and src.source is Ability:
		return src.source
	return null

# The in-battle tooltip's scope adjective. DELEGATES to BlockSchema.scope_words — the one renderer
# the generated prose uses as well — so a counter's card and its tooltip cannot word the same
# authored value two different ways. `classes` is no longer a parameter: this used to resolve the
# list itself and print the raw shortcut for a non-Array, which answered the literal "any" for a
# scope that filters nothing ("The next any skill used on this character will be countered").
func _scope_text(scope) -> String:
	return BlockSchema.scope_words(scope)

# ...ready to sit directly in front of the word "skill": the adjective plus a space, or "" when
# there is no adjective, so "any" collapses to "The next skill" rather than "The next  skill".
func _scope_word(scope) -> String:
	var words := BlockSchema.scope_words(scope)
	return "" if words.is_empty() else words + " "

# The " (except X)" tail a counter/reflect desc hangs off "skill" when an `exclude` subtracts a
# class from the scope. scope_words renders the exclusion as the SAME " or "-joined disjunction the
# scope uses (a skill is let through if it carries ANY excluded class). "" when there is nothing to
# subtract — so the no-exclude desc is byte-for-byte today's, and this is a purely additive clause.
func _except_word(exclude) -> String:
	var words := BlockSchema.scope_words(exclude)
	return "" if words.is_empty() else " (except %s)" % words

func set_explicit_targets(list: Array) -> void:
	_explicit_targets = list

# Bind the payload selectors AND the event magnitude for this run. Called ONLY from the
# trigger/counter/recurring payload closures — a top-level cast leaves all three null, which is what
# makes `holder`/`affected` resolve to nobody and the `event` reading read 0 outside a payload
# instead of quietly meaning something else. `event` is QueryContext.value on the hooks that carry a
# magnitude (damage/healing) and null everywhere else (a counter check, a tick) — the honest 0 floor.
func set_payload_addressing(holder, affected, event = null) -> void:
	_payload_holder = holder
	_payload_affected = affected
	_payload_event = event

func _amount(v) -> int:
	# A scaling amount is an OBJECT ({base, per, cap, div, each}); int({...}) errors, so this branch is
	# genuinely required, not merely additive. (base + per*count) / div, then the MANDATORY cap, then
	# the same 0..max_amount envelope a flat amount answers to.
	if v is Dictionary:
		var base := int(v.get("base", 0))
		var per := int(v.get("per", 0))
		# cap is required by the validator; default to max_amount for a hand-edited file that skipped
		# it, so a missing cap fails SAFE (no bound) rather than to 0 (silently deals nothing).
		var cap := int(v.get("cap", BlockSchema.LIMITS["max_amount"]))
		# div (optional, default 1) makes an author's FRACTION buildable ("reflect 50%" = per:1, div:2):
		# per is an int, so per:0.5 was unbuildable and floored to 0. It divides the WHOLE base+per*count
		# and is applied BEFORE the cap, so `cap` still bounds the FINAL delivered amount (and _amount_hint
		# stays honest scoring at cap). CRASH GUARD: a hand-edited div of 0 is a divide-by-zero — floor it
		# at 1 (the same reject the validator names) so malformed data degrades to "no divisor" mid-resolve
		# instead of crashing the whole ability. Integer division, so authors pick a clean ratio.
		var div := maxi(int(v.get("div", 1)), 1)
		var total := (base + per * _resolve_reading(v.get("each", null))) / div
		return clampi(mini(total, cap), 0, BlockSchema.LIMITS["max_amount"])
	return clampi(int(v), 0, BlockSchema.LIMITS["max_amount"])

# A `times`/`amount` that is EITHER a constant int or a reading object. The runner clamps the
# result to its own limit at the call site, so this only has to hand back the raw number.
func _reading_or_int(v) -> int:
	return _resolve_reading(v) if v is Dictionary else int(v)

# --- value readings ---------------------------------------------------------
# A reading node {read, of, name, effect} -> ONE integer read off the live board. The closed enum
# mirrors compare's `value`; the SAME node resolves here whether it sits in a scaling amount's
# `each`, a compare `value`, or a repeat `times`. See BlockSchema.READINGS for what each reads.
func _resolve_reading(node) -> int:
	if not node is Dictionary:
		return 0
	var read := str(node.get("read", ""))
	# `event` reads the FIRING EVENT'S magnitude off the payload, not the board — it has no selection
	# to fold, so it short-circuits before `of` is resolved. null (outside a payload, or a hook with
	# no magnitude) floors at 0: the validator makes it payload-only, so a live read here has a value.
	if read == "event":
		return int(_payload_event) if _payload_event != null else 0
	# `dead_count` MUST bypass _resolve_targets: that helper drops the dead/banished (see :416-464,
	# _legal_pool), and the dead are the very population this reading counts. Build the fallen roster
	# straight off the team the `of` scope names — short-circuit before `group` is even resolved so the
	# dead-dropping resolve never runs for this read. The validator restricts `of` to the three team
	# pools, so a live read here only ever sees all_allies / other_allies / all_enemies.
	if read == "dead_count":
		return _count_dead(str(node.get("of", "all_enemies")))
	var group := _resolve_targets(node.get("of", "all_enemies"))
	match read:
		"alive_count":
			# _resolve_targets already dropped the dead/banished, so the surviving list IS the count.
			return group.size()
		"hp":
			var s := 0
			for c in group:
				s += int(c.health.hp)
			return s
		"missing_hp":
			var s := 0
			for c in group:
				s += maxi(int(c.health.max_hp) - int(c.health.hp), 0)
			return s
		"energy":
			# Energy is a TEAM pool, not a per-character stat: read the FIRST resolved member's team
			# once. Summing per head would multiply one shared pool by the selection size.
			if group.is_empty():
				return 0
			var team = group[0].team
			return int(team.energy.total_available()) if team != null and team.energy != null else 0
		"stacks":
			var s := 0
			for c in group:
				for e in _matching_effects(c, node):
					s += int(e.stack_count())
			return s
		"effect_count":
			var s := 0
			for c in group:
				s += _matching_effects(c, node).size()
			return s
		"duration":
			var s := 0
			for c in group:
				for e in _matching_effects(c, node):
					# A permanent (-1) contributes 0: "per remaining turn" of something that never ends
					# is not a finite number, and 0 is the honest floor.
					if int(e.duration) > 0:
						s += int(e.duration)
			return s
	push_warning("[blocks] unknown reading '%s' in '%s' — reads as 0" % [read, ability.ability_name])
	return 0

# The FALLEN members of the team a POOL scope names, counted straight off the roster so the dead
# survive the tally. MIRRORS the dead_allies arm in _resolve_pool (:275-279): a member counts iff it
# is a valid instance, is .dead, and is NOT .banished — a banished character is off the board, not
# merely dead (saitama7's "not counting a banished ally"). `of` is restricted by the validator to the
# three team pools; anything else answers 0 rather than guessing a team.
func _count_dead(of: String) -> int:
	var roster: Array = []
	match of:
		"all_enemies":
			roster = _enemy_team()
		"all_allies", "other_allies":
			roster = user.team.characters
		_:
			# The validator forbids a non-team `of` here; a hand-edited one degrades to 0, not a crash.
			return 0
	var n := 0
	for c in roster:
		# other_allies drops the user (a self dead-count is meaningless: a dead caster casts nothing).
		if of == "other_allies" and c == user:
			continue
		if c != null and is_instance_valid(c) and c.dead and not c.banished:
			n += 1
	return n

# The effects on `c` matching a reading's `name` (optional; absent matches any name) and `effect`
# type (optional; absent matches any type), MINUS anything hidden from both players.
#
# THE VISIBILITY FILTER is the same predicate the wire-effects loop uses
# (EffectStorageComponent.get_effect_clusters: `effect.system and not effect.display_system` is
# dropped). Counting a both-players-hidden effect would leak that hidden state as a MAGNITUDE — a
# correctness bug, not just balance: the per-turn drift validator recomputes what each side can see,
# and a damage number that moved on an invisible effect is state the client never received.
func _matching_effects(c, node: Dictionary) -> Array:
	var want_name := str(node.get("name", ""))
	var has_type := node.has("effect")
	var want_type := BlockSchema.immunity_effect_id(str(node.get("effect", ""))) if has_type else -1
	var out: Array = []
	for e in c.effects.get_all_effects():
		if e.system and not e.display_system:
			continue
		if want_name != "" and str(e.effect_name()) != want_name:
			continue
		if has_type and int(e.effect_type) != want_type:
			continue
		out.append(e)
	return out

# The signed sibling of _amount, for the kinds in BlockValidator.SIGNED_AMOUNT_KINDS.
# Symmetric about zero rather than floored at it — same defensive envelope, both ways.
func _signed_amount(v) -> int:
	var cap: int = BlockSchema.LIMITS["max_amount"]
	return clampi(int(v), -cap, cap)

func _string_list(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(str(x))
	return out

# A list of DAMAGE_TYPE names -> a list of DamageType.Type ints, for a damage_boost's
# include_types/exclude_types (the factory's class_targets/exclusion_targets, which get_true_damage
# compares against a hit's damage_type). BlockSchema.damage_type_id maps an unknown name to NORMAL
# rather than erroring — the validator already rejects unknown names, so a name reaching here is
# valid; the fallback is only the hand-edited-file backstop (a bad name degrades to NORMAL, a defined
# type, instead of crashing mid-resolve). Non-Array input yields [] — today's unfiltered behaviour.
func _damage_type_list(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(BlockSchema.damage_type_id(str(x)))
	return out
