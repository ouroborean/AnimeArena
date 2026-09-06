extends RefCounted
class_name BlockValidator

# ============================================================================
# The SECURITY BOUNDARY for authored content.
#
# Players will author these trees, so this validator is the thing standing
# between a submitted JSON blob and the live battle engine. It is strict by
# construction: every op, effect kind, selector, condition and damage type must
# be in BlockSchema's whitelist, every number is range-checked, nesting and
# block counts are bounded, and any unknown field is a rejection rather than a
# shrug. Nothing here interprets strings as code — there is no eval path at all.
#
# Returns a list of human-readable errors ([] == valid). Callers MUST refuse to
# store or run a tree that fails. BlockRunner is additionally defensive at
# runtime, but validation is where bad content is supposed to die.
# ============================================================================

# Effect kinds whose `amount` is a SIGNED magnitude rather than a size. Both of
# them run in BOTH directions in the shipped corpus — 35 ability files apply a
# negative one, e.g. mercury1's Effect.cooldown_mod(-3, 3, ["Shine Aqua Illusion"])
# shaving 3 turns off its own cooldown — so validating them as positive-only was
# enforcement the game itself does not have.
# `damage_boost` joins them: a NEGATIVE amount is a hostile weaken (the shipped ladydevimon3
# Effect.damage_mod_effect(-10, ...)), so the unsigned _validate_amount would reject every weaken
# out of hand exactly as it would a cooldown discount. Its arm below range-checks the signed amount.
const SIGNED_AMOUNT_KINDS := ["cost_change", "cooldown_change", "damage_boost"]

# The authoring `target` modes, mapped to TargetType by Ability._target_type_from_mode.
# Kept here (and exported to the editor through the palette) so the two lists cannot drift.
const TARGET_MODES := ["enemy", "ally", "self", "all_enemies", "all_allies", "everyone"]

# Ability-level BOOLEAN flags the engine actually reads, which an authored skill may set
# directly. They are not classes: character_component.is_stunned() checks `ability.stunnable`
# and match_event_recorder checks `ability.invisible` — the "Unstunnable"/"Invisible" class
# strings are only the labels shown on the skill card. 9 shipped abilities are unstunnable,
# 63 invisible, 20 selfless; without these an authored skill could never be any of those
# things. AuthoredCharacter._build_moveset writes them through, and _authored_palette exports
# THIS list, so a flag leaves the editor by leaving this line.
const ABILITY_FLAGS := ["stunnable", "invisible", "selfless", "accurate"]

# Flags that were offered and are NOT any more, with the reason an author gets told. Kept as
# an explicit list rather than deleted, because a spec already saved with one on disk must be
# told what happened rather than silently doing something different from what it says.
#
# `and_targeter` is meaningless WITHOUT a per-skill splash predicate: get_other_aoe_targets
# only adds an extra character when `used_ability.and_target(character)` says yes
# ("new multiplayer/battle_manager.gd":1878), the four shipped users each hand-write that
# predicate (hawkmon5, kakashi4, koro2, nonon5), and Ability.and_target's base is `return
# false` — which is what a ScriptedAbility inherits. So the flag never ADDED a target; it
# only ever subtracted, and only on one of the two paths: the web client expands an AoE from
# the server's own special_targets without consulting and_target at all (app.js pickTarget),
# while a bot goes through _v3_execute -> get_other_aoe_targets and comes back with nothing
# but the clicked character. Same authored skill, two different target lists depending on who
# is playing it. It comes back in Phase F, next to the splash predicate that gives it a job.
const RETIRED_ABILITY_FLAGS := {
	"and_targeter": "and_targeter is not available: it only narrows an AoE through a per-skill splash rule (Ability.and_target) that an authored skill cannot define yet, so a flagged AoE would hit everyone for a human player and only the clicked target for a bot",
}

# Ability classes the editor no longer offers as a chip, keyed to the message that names the
# replacement. "Action" is the one class the engine reads as "this effect's ticks stop under a stun"
# ("new multiplayer/battle_manager.gd":1225); a bare chip set it with no prose and no validator
# message, silently halving a ticker's uptime. It is now derived from the `recurring` effect's
# stops_when_stunned field (authored_character.gd), which generates prose and writes the class. The
# string stays in Ability.CLASS_NAMES because the ENGINE still reads it — this only removes the
# author's typed lever. Single-sourced so the palette export (which stops the editor drawing the
# chip) and the validator (which rejects a hand-typed one) cannot disagree.
const RETIRED_AUTHOR_CLASSES := {
	"Action": "classes: 'Action' is no longer set directly — it silently stopped an effect's ticks under a stun with nothing on the card. Put stops_when_stunned on the recurring effect that should pause instead",
}

# The class chips the editor may offer: every engine class MINUS the retired ones. Read by the
# authored-content palette export.
static func authorable_classes() -> Array:
	var out: Array = []
	for c in Ability.CLASS_NAMES:
		if not RETIRED_AUTHOR_CLASSES.has(str(c)):
			out.append(str(c))
	return out

# `siblings` is the character's OTHER authored abilities, in the order
# AuthoredCharacter._build_moveset will place them (see moveset_order). It is only
# needed by cross-referencing blocks — today just `swap`, whose `into` names another
# of the author's own skills. It stays optional so a single ability can still be
# validated standalone (the block editor's live preview does exactly that); when it
# is absent the cross-reference is range-checked but not resolved.
static func validate_ability(spec, siblings = null) -> Array:
	var errs: Array = []
	if not spec is Dictionary:
		return ["ability must be an object"]

	var name := str(spec.get("name", "")).strip_edges()
	if name.is_empty():
		errs.append("name is required")
	elif name.length() > 64:
		# GROUNDED-ish: the longest shipped ability name is 38 characters (rengoku3), and the
		# battle UI has to render this inside a button. Comfortable headroom, not a design rule.
		errs.append("name must be 64 characters or fewer")

	# PHASE F — `target` is string-or-object. A string is one of the six legacy modes; an object is a
	# Layer-1 ELIGIBILITY object (mode/shape/only/pick/measure/bypass_invuln/bypass_when/exclude_self/include_dead).
	# `tmode` below is the SIDE either way, so the banish/recurring passes read the same value.
	var tval = spec.get("target", "enemy")
	var tmode := "enemy"
	if tval is Dictionary:
		errs.append_array(_validate_target_object(tval))
		# NOTE: no widened-`shape` AoE product bound here — a whole-faction AoE's total damage is an
		# approver's balance call, not a cap the engine enforces (owner ruling). The structural block/
		# repeat work-ceilings still bound compute.
		tmode = str(tval.get("mode", "enemy"))
	else:
		tmode = str(tval)
		if not tmode in TARGET_MODES:
			errs.append("target must be one of %s (got '%s')" % [", ".join(TARGET_MODES), tmode])

	# Sanity clamp only. Ability.cooldown is a plain int with no engine ceiling; the
	# longest shipped cooldown is 9 (emiyaarcher2), so this is ~10x headroom.
	var cd := int(spec.get("cooldown", 0))
	if cd < 0 or cd > 99:
		errs.append("cooldown must be 0-99")

	errs.append_array(_validate_cost(spec.get("cost", {})))
	errs.append_array(_validate_classes(spec.get("classes", [])))
	# Retired class chips (today just "Action") are rejected on the ability class row — not inside the
	# shared _validate_classes, which stun/counter scopes also use — so the message can name the
	# replacement. See RETIRED_AUTHOR_CLASSES.
	var cls_row = spec.get("classes", [])
	if cls_row is Array:
		for c in cls_row:
			if RETIRED_AUTHOR_CLASSES.has(str(c)):
				errs.append(str(RETIRED_AUTHOR_CLASSES[str(c)]))

	for flag in ABILITY_FLAGS:
		if spec.has(flag) and not spec[flag] is bool:
			errs.append("%s must be true or false" % flag)
	errs.append_array(_validate_channel(spec))
	# max_uses — the per-MATCH charge budget. Stored in a MARK's stack counter, so it is bounded by
	# max_stacks (the same ceiling every stacking resource answers to); 0/absent is unlimited, and the
	# floor is 1 (a 0-use skill would be permanently unusable — the silent-lockout trap).
	if spec.has("max_uses"):
		var mu = spec["max_uses"]
		if not (mu is int or mu is float):
			errs.append("max_uses must be a number")
		elif int(mu) < 1 or int(mu) > BlockSchema.LIMITS["max_stacks"]:
			errs.append("max_uses must be 1-%d (omit it for unlimited)" % BlockSchema.LIMITS["max_stacks"])
	# Only a flag that is actually SET is rejected. A hand-edited file carrying
	# `"and_targeter": false` is asking for the behaviour it already gets, and failing it
	# would strand the character (the registry re-validates on load and refuses to load it).
	for flag in RETIRED_ABILITY_FLAGS:
		if bool(spec.get(flag, false)):
			errs.append(str(RETIRED_ABILITY_FLAGS[flag]))

	# Usage gating reuses the condition vocabulary. Gating in the real engine is arbitrary
	# GDScript composing as many clauses as it likes (extra_usable, 1021 files), so the only
	# reason to bound this at all is evaluation cost — and ScriptedAbility.extra_usable
	# short-circuits, so the bound matches the trigger-payload one rather than being tighter.
	var reqs = spec.get("requires", [])
	if not reqs is Array:
		errs.append("requires must be a list")
	else:
		var max_reqs: int = BlockSchema.LIMITS["max_trigger_then_blocks"]
		if reqs.size() > max_reqs:
			errs.append("requires: at most %d conditions" % max_reqs)
		for i in range(reqs.size()):
			errs.append_array(_validate_condition(reqs[i], "requires[%d]" % i))

	# GROUNDED: no shipped Passive carries a non-zero cooldown (105 checked), and a Passive is
	# run once by Character.startup_passives and never selected, so a cooldown could only ever
	# be a misunderstanding. Deliberately NOT extended to `cost` or `requires` — cooler6
	# ("Cruel Transformation") is a shipped Passive with cost {green: 1}, and passives freely
	# define extra_usable(); both fields are simply never consulted, and calling an inert field
	# fatal blocked the ordinary edit flow of toggling Passive on an existing skill.
	var cls_list = spec.get("classes", [])
	var is_passive: bool = cls_list is Array and "Passive" in cls_list
	if is_passive and int(spec.get("cooldown", 0)) != 0:
		errs.append("a Passive ability must have cooldown 0")

	var blocks = spec.get("blocks", [])
	if not blocks is Array:
		errs.append("blocks must be a list")
		return errs
	if blocks.is_empty():
		errs.append("an ability needs at least one block")
	var counted := _count_blocks(blocks)
	if counted > BlockSchema.LIMITS["max_blocks_per_ability"]:
		errs.append("too many blocks (%d, max %d)" % [counted, BlockSchema.LIMITS["max_blocks_per_ability"]])
	for i in range(blocks.size()):
		errs.append_array(_validate_block(blocks[i], "blocks[%d]" % i, 0, siblings))
	if is_passive:
		for i in range(blocks.size()):
			errs.append_array(_validate_passive_targets(blocks[i], "blocks[%d]" % i, 0))
	# `banish`'s pool rule needs the ABILITY's target mode, which _validate_block never sees, so it
	# rides in its own pass exactly as the Passive rule does.
	# AoE for the banish aim pass: the legacy string modes, OR a Layer-1 object whose shape is "all"
	# (which fans `to: "target"` out to the whole flagged faction, exactly as all_enemies does).
	var aoe: bool = tmode in ["all_enemies", "all_allies", "everyone"]
	if tval is Dictionary:
		aoe = str(tval.get("mode", "")) == "everyone" or str(tval.get("shape", "one")) == "all"
	for i in range(blocks.size()):
		errs.append_array(_validate_banish_targets(blocks[i], "blocks[%d]" % i, 0, aoe, false))
	# The stops_when_stunned CONSISTENCY rule needs every recurring on the whole ability (they share one
	# Action-class switch), so it rides its own pass exactly as banish's aim rule does. (There is no
	# longer a recurring HOSTILE-PLACEMENT duration cap — recurring durations are author-controlled like
	# every effect, per the owner ruling.)
	errs.append_array(_validate_recurring_consistency(blocks))
	# THE COOLDOWN SELF-RESET EXPLOIT guard. It needs the ability's OWN name to spot an op that reduces
	# its own cooldown, which _validate_block never has, so it rides its own pass exactly as banish's
	# aim rule does.
	for i in range(blocks.size()):
		errs.append_array(_validate_cooldown_self_reset(blocks[i], "blocks[%d]" % i, 0, name))
	return errs

# BANISH MAY ONLY EVER AIM AT ONE CHARACTER, and the abuse case is not "a strong skill" — it is an
# INSTANT WIN. check_win_condition ("new multiplayer/battle_manager.gd":1787) returns true when every
# enemy is `dead or banished`, and check_match_over runs after EVERY executed step mid-turn, not only
# at turn end — so a whole-team banish of the shortest duration ends the match as a Victory before it
# can expire. check_lose_condition (:1776) makes the mirror, a whole-team self-banish, an instant
# Defeat. No magnitude or duration cap reaches this; the only bound that works is on the AIM.
#
# TWO ways a block can aim at more than one character, and both are refused:
#   * a POOL SELECTOR (all_enemies / all_allies / other_allies, and the three condition-filtered
#     ones, which resolve to every member the condition holds for);
#   * `to: "target"` — or no `to` at all, which defaults to it — on a skill whose own `target` mode
#     is an AoE. The selector name is innocent; the ability makes it a pool.
# Inside a `then` payload `target` is rebound by BlockRunner.set_explicit_targets to the single
# character who tripped the hook, so the second rule does not apply there — hence the flag.
# BlockRunner._op_banish refuses a >1 resolution independently, because a hand-edited file on disk
# never met this function.
static func _validate_banish_targets(b, path: String, depth: int, aoe_mode: bool, in_payload: bool) -> Array:
	if not b is Dictionary or depth > BlockSchema.LIMITS["max_nesting_depth"]:
		return []
	var errs: Array = []
	var op := str(b.get("op", ""))
	if op == "banish":
		var to_val = b.get("to", "target")
		if to_val is Dictionary:
			# PHASE F — a selector OBJECT. Legal on banish ONLY when it can resolve to at most one
			# character: a POOL_SINGLE pool (main_target / user), or pick:random with count 1. Anything
			# else — a multi pool, or a lowest/highest that includes ties — can resolve to a whole team
			# and banishing them all ends the match on the spot (the runtime _op_banish refuses >1 too).
			var pool := str(to_val.get("pool", "target"))
			var pk := str(to_val.get("pick", "all"))
			var single_ok: bool = pool in BlockSchema.POOL_SINGLE or (pk == "random" and int(to_val.get("count", 1)) == 1)
			if not single_ok:
				errs.append("%s.to: banish must resolve to ONE character — a banish that could hit a whole team ends the match on the spot (a banished character counts as eliminated by the win check, which runs mid-turn). Use pool 'main_target'/'user', or pick:random with count 1" % path)
		else:
			var sel := str(to_val)
			if BlockSchema.is_pool_selector(sel):
				errs.append("%s.to: banish cannot aim at '%s' — banishing a whole team ends the match on the spot (a banished character counts as eliminated by the win check, which runs mid-turn). Aim at one character: the target, the user, a random enemy or a random ally" % [path, sel])
			elif sel == "target" and aoe_mode and not in_payload:
				errs.append("%s.to: this skill targets a whole team, so 'target' here is every one of them and banishing them all ends the match on the spot. Give the block its own single-character 'to' (the user, a random enemy or a random ally), or make the skill single-target" % path)
	# Recurse through the bundling ops and into payloads. A `then` payload sets in_payload, which
	# only relaxes the AoE rule above — the pool-selector rule holds everywhere.
	var subs = b.get("blocks", null)
	if subs is Array:
		for i in range(subs.size()):
			errs.append_array(_validate_banish_targets(subs[i], "%s.blocks[%d]" % [path, i], depth + 1, aoe_mode, in_payload))
	# A branching group's `else` arm runs on the same board — a whole-team banish there is the same win.
	var else_subs = b.get("else", null)
	if else_subs is Array:
		for i in range(else_subs.size()):
			errs.append_array(_validate_banish_targets(else_subs[i], "%s.else[%d]" % [path, i], depth + 1, aoe_mode, in_payload))
	var spec = b.get("effect", null)
	if spec is Dictionary and spec.get("then", null) is Array:
		var then_list: Array = spec["then"]
		for i in range(then_list.size()):
			errs.append_array(_validate_banish_targets(then_list[i], "%s.effect.then[%d]" % [path, i], depth + 1, aoe_mode, true))
	return errs

# THE COOLDOWN SELF-RESET INFINITE-CAST GUARD. execute_ability writes start_cooldown()
# (new multiplayer/battle_manager.gd:1199) BEFORE it calls execute() (:1208-1214), so an ability that
# REDUCES ITS OWN cooldown lands after that write and is instantly usable again — an unbounded cast.
# The ordering is fixed and there is no safe version, so a NEGATIVE `cooldown` op may not name the
# ability that contains it. It "names" it two ways, and both are refused:
#   * `skills` lists its own name;
#   * `skills` is empty/absent — which means "every skill", and every skill includes this one.
# Reducing ANY OTHER skill's cooldown, and lengthening its own, are both fine and pass untouched.
# The name match is deliberately independent of `to`: reducing your own cooldown is the exploit
# whoever you aim it at, and a copied skill (BlockRunner also checks by identity) blurs whose it is.
# Walks payloads and bundles like the banish pass — a self-reset from a reactive `then` is the exploit
# too (the source ability comes back off cooldown a turn early).
static func _validate_cooldown_self_reset(b, path: String, depth: int, own_name: String) -> Array:
	if not b is Dictionary or depth > BlockSchema.LIMITS["max_nesting_depth"]:
		return []
	var errs: Array = []
	if str(b.get("op", "")) == "cooldown" and int(b.get("amount", 0)) < 0:
		var names = b.get("skills", [])
		var names_self: bool = not (names is Array) or (names as Array).is_empty() or str(own_name) in names
		if names_self:
			errs.append("%s: a skill may not reduce its OWN cooldown — the engine writes the cooldown before this block runs, so it would come straight back off and be castable with no limit. Reduce another skill's cooldown, or list only skills other than '%s' (an empty list means every skill, which includes this one)" % [path, own_name])
	var subs = b.get("blocks", null)
	if subs is Array:
		for i in range(subs.size()):
			errs.append_array(_validate_cooldown_self_reset(subs[i], "%s.blocks[%d]" % [path, i], depth + 1, own_name))
	# A self-reset hidden in a branching group's `else` arm is the exploit just the same.
	var else_subs = b.get("else", null)
	if else_subs is Array:
		for i in range(else_subs.size()):
			errs.append_array(_validate_cooldown_self_reset(else_subs[i], "%s.else[%d]" % [path, i], depth + 1, own_name))
	var spec = b.get("effect", null)
	if spec is Dictionary and spec.get("then", null) is Array:
		var then_list: Array = spec["then"]
		for i in range(then_list.size()):
			errs.append_array(_validate_cooldown_self_reset(then_list[i], "%s.effect.then[%d]" % [path, i], depth + 1, own_name))
	return errs

# NOTE: the recurring HOSTILE-PLACEMENT duration cap is GONE (with _validate_recurring_placement and
# _recurring_targets_enemy). A permanent/long ticker planted on an enemy is a strong effect an approver
# weighs before release, not a restriction the engine enforces (the roster ships permanent enemy-facing
# tickers). Per the owner ruling, recurring durations are author-controlled like every other effect —
# there is no validator cap and no runtime clamp (block_runner.gd).

# THE stops_when_stunned CONSISTENCY RULE. stops_when_stunned writes the ABILITY-level `Action`
# class (the gate reads effect.source.classes), so it is one switch for the whole skill: two
# recurring effects on the same ability with DIFFERENT settings cannot both be honoured — one of
# them would silently get the other's behaviour. Rejected rather than resolved silently, which is
# the same reasoning the reserved-register rule uses for two controls that are one number.
static func _validate_recurring_consistency(blocks) -> Array:
	var settings: Array = []
	_collect_recurring_stun_settings(blocks, 0, settings)
	if true in settings and false in settings:
		return ["this skill has two recurring effects with different stops_when_stunned settings, but that switch is set once for the whole skill (it writes the ability's Action class) — make them agree, or split them across two skills"]
	return []

static func _collect_recurring_stun_settings(blocks, depth: int, out: Array) -> void:
	if not blocks is Array or depth > BlockSchema.LIMITS["max_nesting_depth"]:
		return
	for b in blocks:
		if not b is Dictionary:
			continue
		var spec = b.get("effect", null)
		if spec is Dictionary and BlockSchema.canonical_kind(spec.get("kind", "")) == "recurring":
			out.append(bool(spec.get("stops_when_stunned", false)))
		var subs = b.get("blocks", null)
		if subs is Array:
			_collect_recurring_stun_settings(subs, depth + 1, out)
		if spec is Dictionary and spec.get("then", null) is Array:
			_collect_recurring_stun_settings(spec["then"], depth + 1, out)

# ============================================================================================
# PHASE F LAYER 1 — the eligibility OBJECT at `target`.
# ============================================================================================

# The Layer-1 eligibility object: {mode, shape, only, pick, measure, bypass_invuln, bypass_when,
# exclude_self, include_dead}. `only` AND `bypass_when` reuse the CONDITIONS vocabulary with the two
# eligibility guards below (`only` filters WHO is eligible; `bypass_when` decides, per candidate,
# whether the bypass reaches an invulnerable one).
static func _validate_target_object(t: Dictionary) -> Array:
	var errs: Array = []
	var allowed := ["mode", "shape", "only", "pick", "measure", "bypass_invuln", "bypass_when", "exclude_self", "include_dead"]
	# SECURITY BOUNDARY, exactly as blocks/effects/conditions: an unknown key is a control a future
	# reader might honour, so the shape is exhaustive rather than indicative.
	for k in t.keys():
		if not str(k) in allowed:
			errs.append("target: unexpected field '%s' — a target object takes %s" % [str(k), ", ".join(allowed)])
	if not str(t.get("mode", "enemy")) in BlockSchema.TARGET_OBJECT_MODES:
		errs.append("target.mode: must be one of %s (the SIDE; the fan-out is 'shape')" % ", ".join(BlockSchema.TARGET_OBJECT_MODES))
	if t.has("shape") and not str(t["shape"]) in BlockSchema.TARGET_SHAPES:
		errs.append("target.shape: must be 'one' (single) or 'all' (the whole flagged faction)")
	for flag in ["bypass_invuln", "exclude_self", "include_dead"]:
		if t.has(flag) and not t[flag] is bool:
			errs.append("target.%s: must be true or false" % flag)
	# pick — eligibility takes all/lowest/highest only. `random` is a LAYER-2 selection: a random
	# ELIGIBILITY set cannot be shown to the player consistently (target() is re-run several times a
	# turn), the same re-run hazard the `chance` guard names.
	if t.has("pick"):
		var pk := str(t["pick"])
		if pk == "random":
			errs.append("target.pick: a random ELIGIBILITY set cannot be shown to the player — target() is re-run several times a turn, so the highlighted set would change each time. Use pick:random in a block's `to` instead")
		elif not pk in ["all", "lowest", "highest"]:
			errs.append("target.pick: must be 'all', 'lowest' or 'highest'")
	if t.has("measure") and not str(t["measure"]) in BlockSchema.MEASURES:
		errs.append("target.measure: must be one of %s" % ", ".join(BlockSchema.MEASURES))
	# only — the per-candidate predicate list. Bounded by the same short-circuiting cost limit the
	# trigger payload uses (ScriptedAbility.target short-circuits on the first failing predicate).
	var only = t.get("only", [])
	if not only is Array:
		errs.append("target.only: must be a list of conditions")
	else:
		var maxo: int = BlockSchema.LIMITS["max_trigger_then_blocks"]
		if only.size() > maxo:
			errs.append("target.only: at most %d conditions" % maxo)
		for i in range(only.size()):
			errs.append_array(_validate_eligibility_condition(only[i], "target.only[%d]" % i))
	# bypass_when — the GAP-2 PER-CANDIDATE invuln bypass predicate. A single CONDITION, not a list, and
	# it is validated by the SAME _validate_eligibility_condition `only` uses: it earns the two eligibility
	# guards (no `chance`, no `to`-relative selector) for the identical reason — target() is re-run several
	# times a turn, so a predicate that answers differently each run would flag an unstable set. A malformed
	# bypass_when is a crash/lie (the runner would either mis-evaluate it or the card would promise a reach
	# it does not have), so it is REJECTED here rather than silently ignored. Absent leaves the bypass
	# all-or-nothing (class Bypassing / bypass_invuln), which is byte-for-byte the pre-bypass_when behaviour.
	if t.has("bypass_when"):
		errs.append_array(_validate_eligibility_condition(t["bypass_when"], "target.bypass_when"))
	return errs

# An `only` condition, with the two ELIGIBILITY-SPECIFIC guards on top of the ordinary condition
# rules. Both name a real defect target() is re-run into, not a taste.
static func _validate_eligibility_condition(c, path: String) -> Array:
	var errs := _validate_condition(c, path)
	if not c is Dictionary:
		return errs
	# GUARD 1 — REJECT `chance`. target() is re-run from at least four sites a turn
	# (_compute_special_targets, _drop_invuln_targets, _skill_pierces_invuln, _v3_execute); a
	# re-rolled predicate answers differently at each, so the client highlight, the server drop and
	# the bot expansion would disagree about who was hit. It stays legal in a block's `when` (once).
	if str(c.get("cond", "")) == "chance":
		errs.append("%s: `chance` cannot decide eligibility — target() is re-run several times a turn and a re-rolled predicate would flag a different set each time. Put chance on a block's `when` (evaluated once) instead" % path)
	# GUARD 2 — FORBID a `to`-relative selector in a condition slot. `target` reads
	# user.targeter.targets, which is being REBUILT while eligibility runs, so a predicate that reads
	# it observes a half-built list; random_enemy/random_ally spend a seeded roll that, on the same
	# re-runs as guard 1, answers differently each time. A fixed selector (user / an ally or enemy
	# pool) is deterministic during target(). (holder/affected are already payload-only.)
	for slot in ["on", "of", "vs"]:
		if c.has(slot) and str(c[slot]) in ["target", "random_enemy", "random_ally"]:
			errs.append("%s.%s: '%s' reads the cast's own target list or spends a roll, both of which are unstable while eligibility is being computed — an eligibility predicate must read a fixed selector (user, an ally pool or an enemy pool)" % [path, slot, str(c[slot])])
	return errs

# NOTE: the widened-`shape` AoE PRODUCT BOUND (_validate_target_shape_widen / _top_level_hostile_damage)
# is GONE. Widening a skill to a whole faction multiplies its damage across the enemy team — "a
# 100-damage AoE should be designable, it just would not be approved" (owner ruling). That total is a
# balance judgment for the approver, not a cap the engine enforces. The structural work-ceilings
# (max_blocks_per_ability, max_repeat_times, _count_blocks' product) still bound COMPUTE, which is the
# only thing widening cannot walk past.

# The ability-level `channel` flag. A STRING, not a bool, because a skill is CONTROLLED or
# CHANNELED and never both — see BlockSchema.CHANNEL_MODES for what each one ends on.
#
# THE PASSIVE RULE is the only rejection here, and it names a real defect rather than a taste:
# Character.cancel_channels() ends every CHANNEL_CANCEL on the user the moment they take any
# action that is not "Preserves Channel" ("new multiplayer/battle_manager.gd":1202). A Passive
# runs ONCE, at battle start, before anybody has clicked anything — so a channelled Passive's
# entire effect set would be wiped by that character's very first turn, every game, and the card
# would still promise it. `control` is fine there: CONTROL_CANCEL only ends on a stun, death,
# banish or skill seal, which is a coherent thing for a passive to hang its machinery on.
static func _validate_channel(spec: Dictionary) -> Array:
	if not spec.has("channel"):
		return []
	var mode := str(spec["channel"])
	if mode.is_empty():
		return []                       # an editor that cleared the picker; same as absent
	if not mode in BlockSchema.CHANNEL_MODES:
		return ["channel: must be 'control' (ends if the user is stunned, killed or banished) or 'channel' (also ends when they act again)"]
	var cls = spec.get("classes", [])
	if mode == "channel" and cls is Array and "Passive" in cls:
		return ["channel: a Passive cannot be 'channel' — it runs once at battle start and a channel ends the moment its user acts, so the character's first turn would cancel everything the Passive set up. Use 'control', which ends only on a stun, death or banish"]
	return []

# WHEN a Passive runs is the whole rule. Character.startup_passives
# (scripts/character_component.gd:320-323) executes every Passive-classed ability ONCE, at
# battle start, before either player has clicked anything — so `to`'s default, "target"
# (BlockRunner._block_targets, blocks/block_runner.gd:83-84), reads user.targeter.targets
# while it is still EMPTY (:99) and the block hits nobody. Observed, not inferred: the
# editor's blank ability with Passive ticked deals exactly 0 while its generated prose
# promises 15 (training/tests/creator_hardening_a3a5_probe.gd).
#
# This names a rule the GAME has, not one the Creator invented: no shipped passive aims at
# a clicked target either, because at battle start there is not one.
#
# Recurses through `group` — its children run at battle start just the same — but STOPS at
# an effect's `then` payload. A payload runs later, and BlockRunner.set_explicit_targets
# rebinds "target" there to whoever tripped the trigger, which is both correct and the most
# useful passive shape there is ("when I'm hit, hit them back").
static func _validate_passive_targets(b, path: String, depth: int) -> Array:
	if not b is Dictionary or depth > BlockSchema.LIMITS["max_nesting_depth"]:
		return []
	var op := str(b.get("op", ""))
	# `repeat` bundles blocks exactly as `group` does — running them N times does not change WHEN
	# they run, so a passive's empty targeter is just as empty inside one.
	if op == "group" or op == "repeat":
		var errs: Array = []
		var subs = b.get("blocks", [])
		if subs is Array:
			for i in range(subs.size()):
				errs.append_array(_validate_passive_targets(subs[i], "%s.blocks[%d]" % [path, i], depth + 1))
		# A branching group's `else` arm runs at battle start too — its aim is just as empty.
		var else_subs = b.get("else", [])
		if else_subs is Array:
			for i in range(else_subs.size()):
				errs.append_array(_validate_passive_targets(else_subs[i], "%s.else[%d]" % [path, i], depth + 1))
		return errs
	# An op with no `to` in its field list (gain_energy) has no aim to get wrong.
	if not BlockSchema.OPS.has(op) or not "to" in (BlockSchema.OPS[op]["fields"] as Array):
		return []
	if not b.has("to"):
		return ["%s: a Passive runs once at battle start, before anyone has clicked a target, so '%s' has nothing to default to — give it an explicit 'to' (the user, an ally pool or an enemy pool)" % [path, op]]
	# A Layer-2 object pool reads its base population the same way: target/main_target/other_targets
	# come from the (still-empty) targeter, so they hit nobody at battle start exactly as the string
	# "target" does.
	var pool := BlockSchema.to_pool_name(b["to"])
	if pool in ["target", "main_target", "other_targets"]:
		return ["%s.to: '%s' reads the skill's target list, which is empty on a Passive — it runs once at battle start, before anyone has clicked a target; aim at the user, an ally pool or an enemy pool instead" % [path, pool]]
	return []

# THE moveset order, for both the validator and the engine: the 4 visible actives
# in author order, then the Passive, then the hidden skills in author order.
# `swap`'s slot/into index base_abilities at runtime, so validation has to number
# the skills the same way the engine will or the checked index and the indexed skill
# are two different things — AuthoredCharacter._build_moveset therefore CALLS this
# rather than reimplementing it, so the two cannot drift apart.
#
# Visible first is load-bearing, not cosmetic: MovesetComponent.display_abilities()
# is a blind [0..3] slice, so anything ordered ahead of a visible skill steals its
# board slot and pushes a real skill off the wire.
static func moveset_order(abilities) -> Array:
	if not abilities is Array:
		return []
	var visible: Array = []
	var passives: Array = []
	var hidden: Array = []
	for a in abilities:
		# A non-Dictionary entry is already a validation error; dropping it here keeps
		# these indices identical to the ones the built moveset will actually have.
		if not a is Dictionary:
			continue
		var cls = a.get("classes", [])
		if cls is Array and "Passive" in cls:
			passives.append(a)
		elif bool(a.get("hidden", false)):
			hidden.append(a)
		else:
			visible.append(a)
	return visible + passives + hidden

static func _validate_cost(cost) -> Array:
	if not cost is Dictionary:
		return ["cost must be an object"]
	var errs: Array = []
	for k in cost.keys():
		# GROUNDED: an exact mirror of Energy.Type {GREEN, BLUE, WHITE, RED, RANDOM}. A key
		# outside it would index nothing on the energy pool.
		var ik := int(str(k))
		if ik < 0 or ik > 4:
			errs.append("cost key '%s' must be 0-4 (colour index, 4 = Random)" % str(k))
			continue
		# Sanity clamp only. There is NO total-cost check: the engine never sums a cost
		# against a ceiling, and xanxus2 (6) and yuno7 (6) already exceed the 5 this used to
		# enforce. xanxus2 also spends 5 of a single colour, which the old 0-4 rejected.
		var v := int(cost[k])
		if v < 0 or v > 20:
			errs.append("cost[%s] must be 0-20" % str(k))
	return errs

# The whitelist is DERIVED from the engine's own class list (Ability.CLASS_NAMES) rather
# than restated here — a hand-maintained copy is exactly how this check ended up rejecting
# "Invisible" and "Unstunnable", which 15 shipped abilities carry.
static func _validate_classes(classes) -> Array:
	if not classes is Array:
		return ["classes must be a list"]
	var errs: Array = []
	for c in classes:
		if not str(c) in Ability.CLASS_NAMES:
			errs.append("unknown class '%s'" % str(c))
	return errs

# The RUNAWAY GUARD's counter. LIMITS.max_blocks_per_ability bounds WORK — the tree is walked on
# every cast inside turn resolution — so this counts what a cast will EXECUTE, not what the author
# typed.
#
# `repeat` therefore MULTIPLIES its body rather than merely recursing into it. Plain recursion (the
# behaviour the shared `blocks` key already gave it for free) would charge `{"repeat", times: 12}`
# over a 3-block body as 4 blocks while executing 36, and two nested repeats at the depth limit
# would execute 12^4 of them from a tree that counts as single digits — the ceiling multiplied away.
# Multiplication also makes `max_repeat_times` a bound on the PRODUCT without a second rule.
static func _count_blocks(blocks) -> int:
	var n := 0
	if not blocks is Array:
		return 0
	for b in blocks:
		n += 1
		if b is Dictionary:
			# A branching `group`'s `else` blocks EXECUTE (exactly one arm runs), so they count toward
			# the work ceiling the same as `blocks` — the task's "_count_blocks recurses into it".
			if b.get("else", null) is Array:
				n += _count_blocks(b["else"])
			if b.get("blocks", null) is Array:
				var body := _count_blocks(b["blocks"])
				if str(b.get("op", "")) == "repeat":
					# A SCALING `times` (a reading Dictionary) must count at its WORST case, not throw.
					# The old `int(b.get("times",1))` did `int({...})`, which raises "Nonexistent int
					# constructor"; GDScript logs-and-continues, so the multiply silently degraded to
					# times=1 and the 40-block work ceiling was defeated for every scaling repeat —
					# including nested ones, which compounded to ~12^depth resolutions from a tree that
					# statically counted as a handful of blocks. The runtime clamps a reading `times` to
					# max_repeat_times (block_runner.gd:144) and the bot hint scores it there
					# (scripted_ability._times_hint), so that ceiling is the honest static bound too.
					var tv = b.get("times", 1)
					var factor := int(BlockSchema.LIMITS["max_repeat_times"]) if tv is Dictionary else maxi(int(tv), 1)
					body *= factor
				n += body
			var spec = b.get("effect", null)
			if spec is Dictionary and spec.get("then", null) is Array:
				n += _count_blocks(spec["then"])
	return n

# `in_payload` is the PLACEMENT flag for BlockSchema.PAYLOAD_SELECTORS: true only for blocks
# reached through a `trigger`/`counter` `then` list (and through any `group` nested inside one).
# Outside a payload there is no event, so `holder`/`affected` would resolve to nobody — and a
# selector that validates while aiming at nothing is the failure mode this palette keeps having.
# `event_where` rides ALONGSIDE `in_payload` (it does not replace it: in_payload gates the placement
# selectors holder/affected, which are legal in EVERY payload; event_where gates the `event` READING,
# legal only where the hook carries a magnitude). It is "" outside a payload, otherwise the NAME of the
# reactive context — a trigger hook, or the literal "counter"/"recurring" — so _validate_reading can
# both decide (is it in BlockSchema.EVENT_TRIGGERS?) and name the offending context in its message.
static func _validate_block(b, path: String, depth: int, siblings = null, in_payload := false, event_where := "") -> Array:
	var errs: Array = []
	if depth > BlockSchema.LIMITS["max_nesting_depth"]:
		return ["%s: nested too deeply (max %d)" % [path, BlockSchema.LIMITS["max_nesting_depth"]]]
	if not b is Dictionary:
		return ["%s: block must be an object" % path]

	var op := str(b.get("op", ""))
	if not BlockSchema.OPS.has(op):
		return ["%s: unknown op '%s'" % [path, op]]

	# Unknown-field rejection: authored content may not smuggle extra keys. THIS IS THE
	# SECURITY BOUNDARY, not a design rule — it is what stops a submitted JSON blob from
	# carrying keys some future runner branch might read, and it is what makes the palette
	# exhaustive rather than merely indicative. The same check guards effects and conditions.
	var allowed := (BlockSchema.OPS[op]["fields"] as Array).duplicate()
	allowed.append_array(["op", "when"])
	for k in b.keys():
		if not str(k) in allowed:
			errs.append("%s: unexpected field '%s' for op '%s'" % [path, str(k), op])

	if b.has("to"):
		if b["to"] is Dictionary:
			# PHASE F LAYER 2 — a selector object (pool x where x pick x order). It carries its own
			# per-candidate `where`, so the block's `when` stays a whole-block guard (no forced-`when`).
			errs.append_array(_validate_selector_object(b["to"], path + ".to", in_payload))
		else:
			var sel := str(b["to"])
			if BlockSchema.is_payload_selector(sel):
				# Placement, not spelling — so the message says WHERE it belongs rather than
				# "unknown selector", which would send an author looking for a typo.
				if not in_payload:
					errs.append("%s.to: '%s' only means something inside a trigger or counter payload — %s. Out here there is no event to address; aim at the user, the target or a pool instead" % [path, sel, str(BlockSchema.PAYLOAD_SELECTORS[sel])])
			elif not BlockSchema.is_selector(b["to"]):
				errs.append("%s: unknown selector '%s'" % [path, sel])
			# The condition-filtered STRING selectors are the ONE place `when` is mandatory rather than
			# optional: without it "every enemy the condition holds for" has no condition, and the block
			# is either a typo for all_enemies or a silent no-op. The OBJECT form is exempt — its `where`
			# is the per-candidate filter, so its `when` is free to be a whole-block guard (the exact
			# defect Phase F closes: a block gets BOTH now).
			if BlockSchema.FILTERED_SELECTORS.has(sel) and not b.has("when"):
				errs.append("%s: '%s' selects by condition, so it needs an 'only if' — add a 'when'" % [path, sel])
	if b.has("when"):
		# in_payload rides into the block's own `when` so a compare there can read `event` — the
		# whole-block guard sits in the same reactive scope as the ops it gates.
		errs.append_array(_validate_condition(b["when"], path + ".when", in_payload, event_where))

	match op:
		"damage":
			errs.append_array(_validate_amount(b.get("amount", null), path + ".amount", true, in_payload, event_where))
			var dt := str(b.get("damage_type", "NORMAL"))
			if not dt in BlockSchema.DAMAGE_TYPES:
				errs.append("%s: unknown damage_type '%s'" % [path, dt])
		"heal":
			errs.append_array(_validate_amount(b.get("amount", null), path + ".amount", true, in_payload, event_where))
		"gain_energy":
			# The runner LOOPS gain_bonus_energy/gain_random_energy this many times, so the
			# amount is a loop count and max_energy_gain is the loop guard.
			var n := int(b.get("amount", 1))
			var gmax: int = BlockSchema.LIMITS["max_energy_gain"]
			if n < 1 or n > gmax:
				errs.append("%s.amount: must be 1-%d" % [path, gmax])
			# GROUNDED: the energy pool only stores four real colours. Omitting the colour is
			# the seeded roll, which is what every shipped "gain random energy" ability does
			# (aiohto2 says so in as many words).
			if b.has("colour") and not str(b["colour"]) in BlockSchema.GAIN_COLOURS:
				errs.append("%s.colour: must be one of %s" % [path, ", ".join(BlockSchema.GAIN_COLOURS)])
		"cleanse":
			if b.has("scope") and not str(b["scope"]) in BlockSchema.CLEANSE_SCOPES:
				errs.append("%s.scope: must be one of %s" % [path, ", ".join(BlockSchema.CLEANSE_SCOPES)])
			if b.has("name") and str(b["name"]).strip_edges().is_empty():
				errs.append("%s.name: must not be blank" % path)
			if b.has("count"):
				# LOOP GUARD on cleanse_filtered, and already escapable: count 0 (or an absent
				# count) means unlimited, so this caps nothing an author actually wants.
				var cnt := int(b["count"])
				if cnt < 1 or cnt > 100:
					errs.append("%s.count: must be 1-100 (omit it, or use 0, for unlimited)" % path)
		"remove":
			# The effect NAME is the whole match key and is the one required field: without it
			# `remove` would be an untargeted wipe, which is what `cleanse` already is.
			if str(b.get("name", "")).strip_edges().is_empty():
				errs.append("%s.name: name the effect to remove" % path)
			# The type is OPTIONAL — omitting it matches any type carrying that name, which is
			# what an author who only knows the effect by its label wants. When present it is
			# checked against BlockSchema.immunity_effects(), the SAME EffectType-derived list
			# effect_immunity uses; deriving it rather than restating it is why this cannot drift
			# from the enum the way the old hand-written immunity whitelist did.
			if b.has("effect") and not str(b["effect"]) in BlockSchema.immunity_effects():
				errs.append("%s.effect: '%s' is not an effect type (omit it to match any type)" % [path, str(b["effect"])])
			if b.has("stacks"):
				errs.append_array(_validate_remove_stacks(b["stacks"], path))
		"adjust":
			# The same two addressing fields `remove` has, for the same reasons: the NAME is the
			# whole match key (without it `adjust` reaches into an effect it cannot name), and the
			# TYPE is the optional disambiguator, checked against the same EffectType-derived list
			# so the two ops cannot drift on what "that effect" means.
			if str(b.get("name", "")).strip_edges().is_empty():
				errs.append("%s.name: name the effect to adjust" % path)
			if b.has("effect") and not str(b["effect"]) in BlockSchema.immunity_effects():
				errs.append("%s.effect: '%s' is not an effect type (omit it to match any type)" % [path, str(b["effect"])])
			errs.append_array(_validate_adjust_deltas(b, path))
		"banish":
			# Duration only. The AIM is the guard that matters, and it needs the ABILITY's own
			# target mode, so it runs as its own pass (_validate_banish_targets).
			errs.append_array(_validate_duration(b, path))
		"repeat":
			errs.append_array(_validate_repeat_times(b, path, in_payload, event_where))
			var reps = b.get("blocks", [])
			if not reps is Array or reps.is_empty():
				errs.append("%s: repeat needs a non-empty blocks list" % path)
			else:
				for i in range(reps.size()):
					# A repeat INSIDE a payload is still inside it, exactly as a group is.
					errs.append_array(_validate_block(reps[i], "%s.blocks[%d]" % [path, i], depth + 1, siblings, in_payload, event_where))
			# THE PRODUCT BOUND, in one central place. A reading `times` OVER a body that itself carries a
			# reading `amount` is a quadratic in ONE skill: both terms scale with board state at once, and
			# neither the per-block max_amount clamp nor the 40-block ceiling observes their product (each is
			# clamped alone). ABUSE: repeat-per-stack of a damage-per-stack detonates on a stacked board. A
			# CONSTANT times over a scaling amount (bounded 12*cap*targets) and a scaling times over a
			# CONSTANT amount (the existing bound) are both fine — only the two-dynamic combination is out.
			if reps is Array and b.get("times", null) is Dictionary and _body_has_scaling_amount(reps):
				errs.append("%s: a scaling repeat count over a scaling amount is a quadratic in one skill — make either the 'times' or the inner 'amount' a fixed number" % path)
		"break":
			# GROUNDED: shield / barrier / both is complete coverage of the engine's two
			# teardown entry points (shatter_shields, shatter_barrier).
			if not str(b.get("what", "")) in BlockSchema.BREAK_TARGETS:
				errs.append("%s.what: must be one of %s" % [path, ", ".join(BlockSchema.BREAK_TARGETS)])
		"apply":
			errs.append_array(_validate_effect(b.get("effect", null), path + ".effect", depth, siblings))
		"group":
			var subs = b.get("blocks", [])
			if not subs is Array or subs.is_empty():
				errs.append("%s: group needs a non-empty blocks list" % path)
			else:
				for i in range(subs.size()):
					# A group INSIDE a payload is still inside it — the flag rides down.
					errs.append_array(_validate_block(subs[i], "%s.blocks[%d]" % [path, i], depth + 1, siblings, in_payload, event_where))
			# `else` is the EITHER/OR arm: exactly one branch fires on ONE roll of the group's `when`.
			# It needs BOTH a non-empty list AND a `when` — with no `when` the condition is always true,
			# so the else branch could never run (the inert-control trap this palette keeps closing).
			if b.has("else"):
				var elses = b["else"]
				if not elses is Array or elses.is_empty():
					errs.append("%s.else: needs a non-empty blocks list (it is the branch that runs when the `when` is false)" % path)
				else:
					for i in range(elses.size()):
						errs.append_array(_validate_block(elses[i], "%s.else[%d]" % [path, i], depth + 1, siblings, in_payload, event_where))
				if not b.has("when"):
					errs.append("%s: a group with an `else` needs a `when` — without a condition to roll, the first branch always runs and the `else` is dead" % path)
		"execute":
			# hp_below is OPTIONAL — its absence is the unconditional instant kill (a shipped, castable
			# outcome), so requiring it would invent a restriction the game lacks. When present it is a
			# per-target threshold and must be >= 1: a living character always has hp >= 1, so a threshold
			# below that can never fire — the block would be a silent no-op (the exact `chance`-style
			# typo trap). The ceiling is the same sanity envelope every magnitude answers to.
			if b.has("hp_below"):
				var thr := int(b["hp_below"])
				if thr < 1 or thr > BlockSchema.LIMITS["max_amount"]:
					errs.append("%s.hp_below: must be 1-%d — a threshold below 1 can never fire on a living character (hp is always >= 1), so the execute would do nothing" % [path, BlockSchema.LIMITS["max_amount"]])
		"revive":
			# The revive HP. Required and >= 1: a 0-HP revive dies again on the spot, so 0 is the same
			# silent no-op a below-1 execute threshold is, not a valid value. Ceiling is the shared sanity
			# clamp. This is the ONE op whose targets keep the dead (see BlockRunner._revive_targets).
			var rv = b.get("amount", null)
			if rv == null:
				errs.append("%s.amount: name the HP the ally is revived with" % path)
			elif not (rv is int or rv is float):
				errs.append("%s.amount: must be a number" % path)
			elif int(rv) < 1 or int(rv) > BlockSchema.LIMITS["max_amount"]:
				errs.append("%s.amount: must be 1-%d — a 0-HP revive dies again immediately" % [path, BlockSchema.LIMITS["max_amount"]])
		"cooldown":
			# A signed turn DELTA: negative reduces, positive lengthens. Bounded to max_turn_delta — a
			# ±N change is a different quantity from an effect duration (which is uncapped), so it uses the
			# signed-delta sanity envelope, not the removed duration cap. 0-rejected the way every signed
			# field is — an author who typed it meant one direction. The SELF-RESET exploit guard needs the
			# ability's own name and rides its own pass (_validate_cooldown_self_reset), exactly as banish's.
			var cda = b.get("amount", null)
			if cda == null:
				errs.append("%s.amount: required — a whole number of turns (negative reduces, positive lengthens)" % path)
			elif not (cda is int or cda is float):
				errs.append("%s.amount: must be a number" % path)
			elif int(cda) == 0:
				errs.append("%s.amount: must not be 0 — use a negative number to reduce, positive to lengthen" % path)
			elif int(cda) < -BlockSchema.LIMITS["max_turn_delta"] or int(cda) > BlockSchema.LIMITS["max_turn_delta"]:
				errs.append("%s.amount: must be %d..%d" % [path, -BlockSchema.LIMITS["max_turn_delta"], BlockSchema.LIMITS["max_turn_delta"]])
			if b.has("skills"):
				if not b["skills"] is Array:
					errs.append("%s.skills: must be a list of ability names" % path)
				else:
					for sn in b["skills"]:
						if not sn is String or str(sn).strip_edges().is_empty():
							errs.append("%s.skills: each entry must be a non-blank ability name" % path)
		"drain_energy":
			# The points to drain — a LOOP COUNT inside lose_energy (range(val)), so it answers to
			# max_energy_gain, the same loop guard gain_energy uses, not to a magnitude cap.
			var da := int(b.get("amount", 1))
			var dmax: int = BlockSchema.LIMITS["max_energy_gain"]
			if da < 1 or da > dmax:
				errs.append("%s.amount: must be 1-%d" % [path, dmax])
			if b.has("steal") and not b["steal"] is bool:
				errs.append("%s.steal: must be true or false" % path)
		"seal":
			# Duration. Seals are author-controlled like every other effect duration (Esdeath ships 2
			# turns, but there is no engine ceiling), so the shared _validate_duration is all it needs.
			errs.append_array(_validate_duration(b, path))
			# `classes` (class_targets) checks against the engine's own class list — the same derived
			# whitelist stun/counter scopes use, so it cannot drift from the enum.
			if b.has("classes"):
				if not b["classes"] is Array:
					errs.append("%s.classes: must be a list of ability classes" % path)
				else:
					errs.append_array(_validate_classes(b["classes"]))
			# `skills` (ability_targets) and `exclude_skills` (exclusion_targets) are NAME lists — a
			# copied/stolen skill runs from a caster whose slot order differs, so the seal matches by
			# name, never index (the same rule the `cooldown` op documents).
			for fld in ["skills", "exclude_skills"]:
				if b.has(fld):
					if not b[fld] is Array:
						errs.append("%s.%s: must be a list of ability names" % [path, fld])
					else:
						for sn in b[fld]:
							if not sn is String or str(sn).strip_edges().is_empty():
								errs.append("%s.%s: each entry must be a non-blank ability name" % [path, fld])
			if b.has("bypassing") and not b["bypassing"] is bool:
				errs.append("%s.bypassing: must be true or false" % path)
	return errs

# PHASE F LAYER 2 — the block selector object {pool, where, pick, order, bypassing, measure, count}.
static func _validate_selector_object(obj: Dictionary, path: String, in_payload: bool) -> Array:
	var errs: Array = []
	var allowed := ["pool", "where", "pick", "order", "bypassing", "measure", "count"]
	for k in obj.keys():
		if not str(k) in allowed:
			errs.append("%s: unexpected field '%s' — a selector object takes %s" % [path, str(k), ", ".join(allowed)])
	var pool := str(obj.get("pool", "target"))
	if not BlockSchema.POOLS.has(pool):
		errs.append("%s.pool: must be one of %s" % [path, ", ".join(BlockSchema.POOLS.keys())])
	if obj.has("order") and not str(obj["order"]) in BlockSchema.ORDERS:
		errs.append("%s.order: must be 'clicked_first' (leads with the primary target) or 'pool' (roster order)" % path)
	if obj.has("bypassing") and not obj["bypassing"] is bool:
		errs.append("%s.bypassing: must be true or false" % path)
	if obj.has("measure") and not str(obj["measure"]) in BlockSchema.MEASURES:
		errs.append("%s.measure: must be one of %s" % [path, ", ".join(BlockSchema.MEASURES)])
	var pick := str(obj.get("pick", "all"))
	if not pick in BlockSchema.PICKS:
		errs.append("%s.pick: must be one of %s" % [path, ", ".join(BlockSchema.PICKS)])
	if obj.has("count"):
		var cnt = obj["count"]
		# A COUNT only means something for pick:random — it is how many to draw. lowest/highest include
		# every tie and 'all' takes the whole pool, so a count there is a field that renders and does
		# nothing (the `trigger_once` failure mode). The runtime clamps it to the pool size, so a big
		# number is harmless; this is a sanity range only.
		if pick != "random":
			errs.append("%s.count: only pick:random uses a count — 'lowest'/'highest' include every tie and 'all' takes the whole pool" % path)
		elif not (cnt is int or cnt is float) or int(cnt) < 1 or int(cnt) > 99:
			errs.append("%s.count: must be 1-99 (how many distinct characters to draw)" % path)
	# WHERE — same condition list as an eligibility `only`, evaluated per candidate. It runs at
	# EXECUTE time (targeter.targets is fully built), so a `target`-reading predicate is FINE here —
	# unlike `only`, which is why guard 2 does not apply. Guard 1 (`chance`) still does.
	var where = obj.get("where", [])
	if not where is Array:
		errs.append("%s.where: must be a list of conditions" % path)
	else:
		var maxw: int = BlockSchema.LIMITS["max_trigger_then_blocks"]
		if where.size() > maxw:
			errs.append("%s.where: at most %d conditions" % [path, maxw])
		for i in range(where.size()):
			errs.append_array(_validate_where_condition(where[i], "%s.where[%d]" % [path, i]))
	return errs

# A `where` condition. Same rules as any condition, plus GUARD 1: `chance` cannot pick targets. A
# selector is re-resolved by the client highlight, the server and the bot, and a re-rolled predicate
# would disagree on who was hit. It stays legal on the block's `when` (evaluated exactly once).
static func _validate_where_condition(c, path: String) -> Array:
	var errs := _validate_condition(c, path)
	if c is Dictionary and str(c.get("cond", "")) == "chance":
		errs.append("%s: `chance` cannot pick targets — a selector is re-resolved by the client, the server and the bot, and a re-rolled predicate would disagree on who was hit. Put chance on the block's `when` (evaluated once) instead" % path)
	return errs

static func _validate_effect(spec, path: String, depth: int, siblings = null) -> Array:
	if not spec is Dictionary:
		return ["%s: effect must be an object" % path]
	var errs: Array = []
	# canonical_kind resolves the pre-rename alias ("reactive" -> "trigger"). Everything
	# below — including every error message — then speaks the CURRENT name only.
	var kind := BlockSchema.canonical_kind(spec.get("kind", ""))
	if not BlockSchema.EFFECT_KINDS.has(kind):
		return ["%s: unknown effect kind '%s'" % [path, str(spec.get("kind", ""))]]

	var allowed := (BlockSchema.EFFECT_KINDS[kind]["fields"] as Array).duplicate()
	# `ticks` is accepted on EVERY kind — see BlockSchema.spec_duration. It is the raw engine
	# duration, and without it the 2N conversion makes every odd duration the roster uses
	# (toudou1's counter 3, broly2's 5, rimuru2's paralyze 3, alphonse5's def_negate 1)
	# unreachable no matter what an author types.
	allowed.append_array(["kind", "damage_type", "ticks"])
	# ...and so is the whole UNIVERSAL set. This is what replaced the per-kind allow-lists:
	# a field that belongs to the Effect rather than to one factory is legal everywhere, and
	# a new effect kind inherits all of them without touching this function.
	allowed.append_array(BlockSchema.UNIVERSAL_EFFECT_FIELDS.keys())
	for k in spec.keys():
		if not str(k) in allowed:
			errs.append("%s: unexpected field '%s' for effect '%s'" % [path, str(k), kind])
	errs.append_array(_validate_reserved_fields(spec, kind, path))
	errs.append_array(_validate_universal_fields(spec, path))

	errs.append_array(_validate_duration(spec, path))
	# cost/cooldown modifiers author a SIGNED magnitude, so they range-check their own
	# `amount` below; the shared _validate_amount is unsigned and would reject every
	# discount out of hand.
	if spec.has("amount") and not kind in SIGNED_AMOUNT_KINDS:
		errs.append_array(_validate_amount(spec["amount"], path + ".amount"))
	# Phase C per-row balance guards, driven ENTIRELY by BlockSchema.SIMPLE_EFFECTS[kind].limits so a
	# row's guard is one more data field, not a branch here. Each limit names its abuse case at the
	# table.
	errs.append_array(_validate_simple_limits(spec, kind, path))
	if spec.has("damage_type") and not str(spec["damage_type"]) in BlockSchema.DAMAGE_TYPES:
		errs.append("%s: unknown damage_type '%s'" % [path, str(spec["damage_type"])])

	match kind:
		"mark":
			var ceiling := int(spec.get("max", 1))
			var cap: int = BlockSchema.LIMITS["max_stacks"]
			if ceiling < 1 or ceiling > cap:
				errs.append("%s.max: must be 1-%d" % [path, cap])
			var initial := int(spec.get("stacks", 1))
			if initial < 1:
				errs.append("%s.stacks: must be at least 1" % path)
			elif initial > ceiling:
				errs.append("%s.stacks: cannot start above max (%d > %d)" % [path, initial, ceiling])
		"stun":
			errs.append_array(_validate_classes(spec.get("exclude_classes", [])))
		"vulnerability":
			# include_types (class_targets, INCLUDE) / exclude_types (exclusion_targets, EXCLUDE) are
			# DAMAGE-TYPE lists get_true_damage compares against a hit's damage_type — the SAME filter
			# damage_boost validates below, NOT ability classes. `amount` stays UNSIGNED: it is checked by
			# the shared _validate_amount pass above (vulnerability is NOT a SIGNED_AMOUNT_KIND — a
			# vulnerability is only ever "more damage taken"). Absent = today's unfiltered behaviour, so
			# each list is checked only when present.
			errs.append_array(_validate_damage_type_list(spec.get("include_types", null), path + ".include_types"))
			errs.append_array(_validate_damage_type_list(spec.get("exclude_types", null), path + ".exclude_types"))
		"damage_boost":
			errs.append_array(_validate_named_skills(spec.get("skills", null), path + ".skills"))
			# SIGNED like cost/cooldown: positive boosts, negative weakens, 0 rejected (an author who
			# typed it meant one direction). Skipped by the shared unsigned pass above via SIGNED_AMOUNT_KINDS.
			errs.append_array(_validate_signed_amount(spec.get("amount", null), path + ".amount"))
			# include_types (class_targets, INCLUDE) / exclude_types (exclusion_targets, EXCLUDE) are
			# DAMAGE-TYPE lists get_true_damage compares against a hit's damage_type — NOT ability classes.
			# Absent = today's unfiltered behaviour, so each is checked only when present.
			errs.append_array(_validate_damage_type_list(spec.get("include_types", null), path + ".include_types"))
			errs.append_array(_validate_damage_type_list(spec.get("exclude_types", null), path + ".exclude_types"))
		"cooldown_change":
			errs.append_array(_validate_named_skills(spec.get("skills", null), path + ".skills"))
			errs.append_array(_validate_signed_amount(spec.get("amount", null), path + ".amount"))
		"cost_change":
			errs.append_array(_validate_named_skills(spec.get("skills", null), path + ".skills"))
			errs.append_array(_validate_cost_change(spec, path))
		"effect_immunity":
			var imm := BlockSchema.immunity_effects()
			if not str(spec.get("effect", "")) in imm:
				errs.append("%s.effect: '%s' is not an effect type" % [path, str(spec.get("effect", ""))])
		"swap":
			errs.append_array(_validate_swap(spec, path, siblings))
		"counter":
			# `scope` is either one of the named shortcuts or a literal list of ability
			# classes — counter_effect's class_targets is a free list, and nine shipped
			# counters filter by a class no shortcut spells (korra1-4, uzui3, maka4,
			# tokoyami3, tsunayoshi2). The duration is author-controlled like every other
			# effect: a counter is SPENT when it fires (default_counter_trigger consumes it),
			# so the duration only bounds how long it waits, not how many skills it eats —
			# which is why broly2 ships 5 and toudou1 ships 3.
			var scope = spec.get("scope", "")
			if scope is Array:
				errs.append_array(_validate_classes(scope))
			elif not BlockSchema.COUNTER_SCOPES.has(str(scope)):
				errs.append("%s.scope: must be one of %s, or a list of ability classes" % [path, ", ".join(BlockSchema.COUNTER_SCOPES.keys())])
			# `exclude` SUBTRACTS a class from the scope — "Harmful except Strategic", the shipped
			# saitama4 shape. Same vocabulary as scope and validated the same way (a shortcut name or a
			# raw class list, unknown classes rejected). OPTIONAL: absent means "subtract nothing" and is
			# byte-for-byte today's behaviour, so it is only checked when present.
			errs.append_array(_validate_exclude(spec, path))
			# WHICH SIDE it watches. Optional, defaulting to the only shape that existed before.
			if spec.has("on") and not str(spec["on"]) in BlockSchema.COUNTER_SIDES:
				errs.append("%s.on: must be 'incoming' (counters skills used ON the character carrying this) or 'outgoing' (counters the skills they use themselves)" % path)
			# from_counter_check threads no magnitude, so `event` reads 0 in a counter payload — reject it
			# by passing the context name (never in EVENT_TRIGGERS).
			errs.append_array(_validate_payload(spec.get("then", []), path, depth, kind, siblings, "counter"))
		"reflect":
			errs.append_array(_validate_reflect(spec, path))
		"redirect":
			errs.append_array(_validate_redirect(spec, path))
		"trigger":
			var trig := str(spec.get("trigger", ""))
			if not BlockSchema.TRIGGERS.has(trig):
				errs.append("%s: unknown trigger '%s'" % [path, trig])
			errs.append_array(_validate_trigger_scope(spec, trig, path))
			# The hook name IS the event_where — _validate_reading checks it against EVENT_TRIGGERS, so
			# `event` is legal on the damage/healing hooks and rejected (named) on the magnitude-less ones.
			errs.append_array(_validate_payload(spec.get("then", []), path, depth, kind, siblings, trig))
		"recurring":
			# `first` decides WHEN the first tick lands (this turn vs next); an unknown value would
			# silently fall to the "next" default and ship a card that is a turn off.
			if spec.has("first") and not str(spec["first"]) in BlockSchema.RECURRING_FIRSTS:
				errs.append("%s.first: must be 'now' (the first tick lands this turn) or 'next' (from your next turn)" % path)
			# stops_when_stunned writes the ability-level Action class; it has to be a real bool, not a
			# truthy string, or the halved-uptime-under-stun behaviour turns on by accident.
			if spec.has("stops_when_stunned") and not spec["stops_when_stunned"] is bool:
				errs.append("%s.stops_when_stunned: must be true or false" % path)
			# from_effect_end threads no magnitude, so `event` reads 0 in a recurring/turn payload — reject
			# it by passing the context name (never in EVENT_TRIGGERS).
			errs.append_array(_validate_payload(spec.get("then", []), path, depth, kind, siblings, "recurring"))
		"portrait_change":
			# LIE-guard, NOT a balance cap: `index` picks an uploaded alt-portrait slot, and an index past
			# the alt slots would 404 client-side and fall back to the DEFAULT portrait — the card would
			# promise a transform that never shows. Bound to the alt-slot COUNT (not a fixed number) so it
			# grows automatically when ALT_PORTRAIT_SLOTS does. `mag` is refused via the row's reserves entry
			# (_validate_reserved_fields) so a universal mag cannot masquerade as the index.
			var alt_count: int = AuthoredAssets.alt_portrait_slots().size()
			var idx := int(spec.get("index", 0))
			if idx < 0 or idx >= alt_count:
				errs.append("%s.index: must be 0-%d (there are %d alternate-portrait slots)" % [path, alt_count - 1, alt_count])
	return errs

# `cost_change`.mode — WHICH of Ability.cost()'s three mechanics this is. The three take
# genuinely different arguments, so the checks branch rather than sharing one shape:
#
#   add  (default) — a SIGNED delta of one colour. 0 is rejected for the reason
#         _validate_signed_amount always rejects it: an author who typed it meant one direction or
#         the other, and a silently inert effect is the worst thing to hand back.
#   set            — the whole new price, so the amount is UNSIGNED and 0 is the point: it is the
#         only way to author "this skill is free", which is a shape the roster ships (Mavis's
#         Fairy Star Strategy). A negative price is not a thing the energy pool can hold.
#   swap           — no amount at all; it moves whatever the skill already costs from one colour to
#         another and the total never changes.
#
# The two fields each mode does NOT use are REJECTED rather than ignored. That is the same rule
# `trigger`.scope answers to: a field that renders, validates and does nothing is the failure mode
# this palette keeps having, and here it is worse than usual — an author who writes an `amount` on
# a swap has written a number they will watch not happen.
static func _validate_cost_change(spec: Dictionary, path: String) -> Array:
	var errs: Array = []
	var mode := str(spec.get("mode", "add"))
	if not mode in BlockSchema.COST_MODES:
		return ["%s.mode: must be one of %s" % [path, ", ".join(BlockSchema.COST_MODES)]]
	if not str(spec.get("colour", "")) in BlockSchema.COST_COLOURS:
		errs.append("%s.colour: must be one of %s" % [path, ", ".join(BlockSchema.COST_COLOURS)])
	match mode:
		"set":
			var v = spec.get("amount", null)
			if v == null:
				errs.append("%s.amount: required — 'set' replaces the whole cost, and 0 means the skill becomes free" % path)
			elif not (v is int or v is float):
				errs.append("%s.amount: must be a number" % path)
			elif int(v) < 0 or int(v) > BlockSchema.LIMITS["max_amount"]:
				errs.append("%s.amount: must be 0-%d — this is the new price, not a change to it, so it cannot be negative" % [path, BlockSchema.LIMITS["max_amount"]])
		"swap":
			if spec.has("amount"):
				errs.append("%s.amount: a colour swap moves whatever the skill already costs, so there is no amount to set — remove it, or use mode 'add'/'set'" % path)
			var from_col := str(spec.get("from", ""))
			if not from_col in BlockSchema.COST_COLOURS:
				errs.append("%s.from: a colour swap needs the colour it replaces (one of %s)" % [path, ", ".join(BlockSchema.COST_COLOURS)])
			elif from_col == str(spec.get("colour", "")):
				errs.append("%s.from: swapping %s for itself changes nothing — name the colour the skill used to cost" % [path, from_col])
		_:
			errs.append_array(_validate_signed_amount(spec.get("amount", null), path + ".amount"))
	if mode != "swap" and spec.has("from"):
		errs.append("%s.from: only a colour swap replaces one colour with another — drop it, or set mode to 'swap'" % path)
	return errs

# `exclude` on a `counter` / `reflect` — the class list SUBTRACTED from the scope, so a counter can
# watch "Harmful EXCEPT Strategic" (the shipped saitama4 shape). Same vocabulary as scope — a shortcut
# NAME or a raw class list — and validated exactly the same way, unknown classes rejected. OPTIONAL:
# absent means "subtract nothing" and is byte-for-byte today's behaviour, so an absent field is a clean
# pass. Shared by both kinds because the field, the resolution path (counter_classes) and the effect
# register (exclusion_targets) are all shared.
static func _validate_exclude(spec: Dictionary, path: String) -> Array:
	if not spec.has("exclude"):
		return []
	var exclude = spec["exclude"]
	if exclude is Array:
		return _validate_classes(exclude)
	if not BlockSchema.COUNTER_SCOPES.has(str(exclude)):
		return ["%s.exclude: must be one of %s, or a list of ability classes" % [path, ", ".join(BlockSchema.COUNTER_SCOPES.keys())]]
	return []

# `reflect` — the two fields that are the whole authoring decision, plus the one universal field
# that would silently fight them.
static func _validate_reflect(spec: Dictionary, path: String) -> Array:
	var errs: Array = []
	# Same vocabulary as `counter`.scope, and the same reason for the raw-list form: class_targets
	# is a free list and every shipped reflect passes ["Harmful"].
	if spec.has("scope"):
		var scope = spec["scope"]
		if scope is Array:
			errs.append_array(_validate_classes(scope))
		elif not BlockSchema.COUNTER_SCOPES.has(str(scope)):
			errs.append("%s.scope: must be one of %s, or a list of ability classes" % [path, ", ".join(BlockSchema.COUNTER_SCOPES.keys())])
	# `exclude` is the same subtraction `counter` carries — reflect stores exclusion_targets too — so
	# it takes the same vocabulary and the same optional/absent-is-today rule.
	errs.append_array(_validate_exclude(spec, path))
	if spec.has("destination") and not str(spec["destination"]) in BlockSchema.REFLECT_DESTINATIONS:
		errs.append("%s.destination: must be 'attacker' (bounce the skill back at whoever used it) or 'applier' (it lands on whoever cast this reflect instead)" % path)
	if spec.has("charges"):
		var ch = spec["charges"]
		if not (ch is int or ch is float) or not int(ch) in BlockSchema.REFLECT_CHARGES:
			# The bound is the ENGINE'S, not an invented one, and the message says so: an author
			# who types 3 has to learn that the number cannot mean what it looks like, rather than
			# ship a skill whose card promises three and delivers one.
			errs.append("%s.charges: must be -1 (every skill, for the whole duration) or 1 (the next skill only) — the engine consumes the whole reflect the first time it fires, so any other number would behave exactly like 1" % path)
	# NOTE: the universal `stacks` (the charge register) and the universal `mag` (the DESTINATION
	# register) are both rejected here, but no longer BY this function — they are the reflect row's
	# `reserves` entry in BlockSchema.EFFECT_KINDS, enforced for every kind by
	# _validate_reserved_fields. This special case was the original of that rule; folding it in is
	# what stopped `mag` (the same defect, on the same effect, with a live Character in the register)
	# from needing a second hand-written case, and what stops Phase C's kinds from needing twenty more.
	return errs

# `redirect` — the two authoring decisions: HOW MUCH of each hit moves (`amount`, a percentage) and
# WHERE it goes (`destination`, a Phase F selector object resolved at redirect time).
static func _validate_redirect(spec: Dictionary, path: String) -> Array:
	var errs: Array = []
	# `amount` is a PERCENTAGE. It is range-checked here as 0-100 rather than by the shared
	# _validate_amount (which allows up to max_amount): above 100% the redirect deals the absorber more
	# than the hit and drives the holder's incoming damage negative — a self-heal — the same
	# reader-maths inversion percent_dr/heal_cut/dodge guard at 100. This is a correctness rail, not a
	# balance cap: it rejects a spec whose card would promise the opposite of what happens.
	if spec.has("amount"):
		var a = spec["amount"]
		if not (a is int or a is float):
			errs.append("%s.amount: must be a number" % path)
		elif int(a) < 0 or int(a) > 100:
			errs.append("%s.amount: must be 0-100 — it is the PERCENTAGE of each hit redirected, and above 100%% the redirect would heal the holder and over-charge the absorber (the card would say the opposite of what happens)" % path)
	# `destination` is REQUIRED and must be a Phase F selector OBJECT — the same pool x where x pick
	# card any other target-finding effect uses. A redirect with nowhere to send the damage is
	# meaningless, and a bare string here would read as a plain selector that could resolve to a whole
	# team (a redirect must move a hit to ONE absorber); the object form is what the runner resolves and
	# what keeps a live Character out of author data.
	if not spec.has("destination"):
		errs.append("%s.destination: required — a redirect needs a character to send the damage to (a selector object: pool/where/pick)" % path)
	elif not spec["destination"] is Dictionary:
		errs.append("%s.destination: must be a selector object (pool/where/pick), not '%s' — that is what resolves to the absorber at redirect time and keeps a live character out of the saved data" % [path, str(spec["destination"])])
	else:
		errs.append_array(_validate_selector_object(spec["destination"], path + ".destination", false))
	return errs

# `trigger`.scope — the EVENT-CLASS filter. Same vocabulary as `counter`.scope (a named shortcut
# or a raw list of ability classes), and the same reason for the raw list: class_targets is a free
# list and nine shipped counters filter by a class no shortcut spells.
#
# THE PLACEMENT RULE is the part with teeth. Four of the ten hooks are dispatched through
# QueryContext.from_effect_end, which sets `source` to the trigger effect ITSELF rather than to a
# skill (scripts/query_context.gd:43) — so a scope there would compare the authored ability with
# its own classes and read the same way on every single fire. Rejecting it is the guard against
# the `trigger_once` failure mode: a control that renders, validates, and does nothing.
static func _validate_trigger_scope(spec: Dictionary, trig: String, path: String) -> Array:
	if not spec.has("scope"):
		return []
	var errs: Array = []
	var scope = spec["scope"]
	if scope is Array:
		errs.append_array(_validate_classes(scope))
	elif not BlockSchema.COUNTER_SCOPES.has(str(scope)):
		errs.append("%s.scope: must be one of %s, or a list of ability classes" % [path, ", ".join(BlockSchema.COUNTER_SCOPES.keys())])
	# Only complain about placement on a trigger name we RECOGNISE — an unknown hook already has
	# its own error, and a second one about that hook's capabilities is noise.
	if BlockSchema.TRIGGERS.has(trig) and not trig in BlockSchema.SCOPED_TRIGGERS:
		errs.append("%s.scope: '%s' does not fire from a skill, so there is no class to filter on — drop the scope, or watch a hook that does (%s)" % [path, trig, ", ".join(BlockSchema.SCOPED_TRIGGERS)])
	return errs

# THE RESERVED-REGISTER RULE, general over every kind. See BlockSchema.EFFECT_KINDS' `reserves`
# column for the measured defects and for why `mag` is not banned outright.
#
# THE ABUSE CASE, in one sentence: the universal pass runs AFTER the factory
# (BlockRunner._apply_universal_fields), so where the factory already wrote that register from one
# of the kind's own authored fields, the author has filled in TWO controls that are one number and
# exactly one of them is a lie. On `reflect` that lie is a live Character replaced by an int, which
# raises "Nonexistent function 'check_ability_receive_triggers' in base 'int'" mid-turn; on
# `effect_immunity` it is a card promising stun immunity and an effect delivering immunity to
# EffectType 0; on `mark` it is `show_stacks: false` with the pip counter showing anyway.
#
# This SUBSUMES the hand-written `reflect`.stacks rejection stage 3 shipped — that case is now the
# `reserves` entry {"stacks": "charges"} on the reflect row, and its reasoning ("they are the same
# number to the engine, so setting both makes one of them silently wrong") is the message below,
# generalised. A per-kind rule in a per-kind validate function is a rule the next twenty kinds
# will not have.
static func _validate_reserved_fields(spec: Dictionary, kind: String, path: String) -> Array:
	var errs: Array = []
	var reserved := BlockSchema.reserved_fields(kind)
	for f in reserved.keys():
		var key := str(f)
		if not spec.has(key):
			continue
		errs.append("%s.%s: '%s' is not settable on a '%s' effect — the engine keeps this effect's '%s' in that same register, so setting both makes one of them silently wrong. Change '%s' instead" % [path, key, key, kind, str(reserved[f]), str(reserved[f])])
	return errs

# PHASE C PER-ROW GUARDS. Every limit is DATA on the Simple Effect row (limits.*). Only ONE guard shape
# remains:
#   * amount_max — a READER-MATHS CEILING, not a balance cap: above it a percentage/chance effect INVERTS
#                  its own maths (PERCENT_DR > 100 heals the attacker; HEAL_CUT > 100 turns a heal into
#                  damage; DODGE_CHANCE > 100 is meaningless). Keeping it stops a spec whose card promises
#                  one thing and does the opposite — a correctness rail, not a strength cap.
# The `forbid_permanent` / `max_turns` PER-ROW DURATION CAPS (isolate / ignore_non_damage / immortality)
# were invented balance caps and are GONE per the owner ruling — those durations are author-controlled
# like every effect, and their strength is an approver's call. A row with an empty `limits` map (now the
# common case) is not touched here at all.
static func _validate_simple_limits(spec: Dictionary, kind: String, path: String) -> Array:
	var errs: Array = []
	if not BlockSchema.SIMPLE_EFFECTS.has(kind):
		return errs
	var limits: Dictionary = BlockSchema.SIMPLE_EFFECTS[kind].get("limits", {}) as Dictionary
	if limits.is_empty():
		return errs
	if limits.has("amount_max") and spec.has("amount"):
		var v = spec["amount"]
		if (v is int or v is float) and int(v) > int(limits["amount_max"]):
			# 100 is the reader's ceiling, not an invented one — see the row's abuse-case comment.
			errs.append("%s.amount: must be at most %d for a '%s' effect (above it the effect inverts its own maths)" % [path, int(limits["amount_max"]), kind])
	return errs

# The universal effect fields (BlockSchema.UNIVERSAL_EFFECT_FIELDS). Type-checked here, and
# clamped again by the runner — a hand-edited file never meets this function. The bounds are
# the SAME shared LIMITS, so validator and runner cannot disagree about what is in range.
static func _validate_universal_fields(spec: Dictionary, path: String) -> Array:
	var errs: Array = []
	for k in BlockSchema.UNIVERSAL_EFFECT_FIELDS.keys():
		var key := str(k)
		if not spec.has(key):
			continue
		var v = spec[key]
		match str(BlockSchema.UNIVERSAL_EFFECT_FIELDS[key]):
			"bool":
				if not v is bool:
					errs.append("%s.%s: must be true or false" % [path, key])
			"int":
				if not (v is int or v is float):
					errs.append("%s.%s: must be a whole number" % [path, key])
				else:
					errs.append_array(_validate_universal_int(key, int(v), path))
			"string":
				if not v is String:
					errs.append("%s.%s: must be text" % [path, key])
	return errs

# Only the two universal ints that have a MEANING to bound are bounded, and both borrow an
# existing LIMIT rather than inventing one. unique_render_id is an opaque grouping key — any
# integer is as valid as any other — so it is deliberately unbounded. The two strings are
# unbounded for the same reason `mark`.text always has been: bounding them would be a new
# restriction on authored content that hand-written kits do not have.
static func _validate_universal_int(key: String, n: int, path: String) -> Array:
	match key:
		"stacks":
			var cap: int = BlockSchema.LIMITS["max_stacks"]
			if n < 1 or n > cap:
				return ["%s.stacks: must be 1-%d" % [path, cap]]
		"mag":
			var mcap: int = BlockSchema.LIMITS["max_amount"]
			if n < -mcap or n > mcap:
				return ["%s.mag: must be %d..%d" % [path, -mcap, mcap]]
	return []

# The nested block list shared by `trigger`, `counter` and `recurring`. `event_where` names the reactive
# context these blocks run in so an `event` reading inside can be checked against BlockSchema.EVENT_TRIGGERS:
# a trigger passes its hook name (magnitude-carrying only when it is in that set), while counter and
# recurring pass their own literal — neither ever threads a magnitude, so `event` is rejected wholesale there.
static func _validate_payload(then, path: String, depth: int, kind: String, siblings, event_where := "") -> Array:
	var errs: Array = []
	if not then is Array or then.is_empty():
		return ["%s: %s needs a non-empty 'then' block list" % [path, kind]]
	if then.size() > BlockSchema.LIMITS["max_trigger_then_blocks"]:
		return ["%s: %s 'then' has too many blocks (max %d)" % [path, kind, BlockSchema.LIMITS["max_trigger_then_blocks"]]]
	for i in range(then.size()):
		# A trigger inside a trigger is the one shape that could recurse
		# without bound at runtime, so nesting is charged double here.
		# in_payload: THIS is where BlockSchema.PAYLOAD_SELECTORS become legal.
		errs.append_array(_validate_block(then[i], "%s.then[%d]" % [path, i], depth + 2, siblings, true, event_where))
	return errs

# The shared duration check for every effect kind. Effect durations are AUTHOR-CONTROLLED and
# UNBOUNDED — exactly as in the shipped engine, which is full of permanent and long-lived effects.
# `turns` (author turns, converted 2N by turns_to_duration) and `ticks` (raw engine duration) each
# accept ANY integer, and ANY negative is the engine's "permanent" (both turns_to_duration and
# spec_duration coerce every <0 to -1). There is deliberately NO ceiling here: the earlier max_turns
# duration cap was an invented limit, removed per the owner ruling (balance is an author/approval
# concern). The only check left is a type check — a non-number would crash the int() coercion downstream.
static func _validate_duration(spec: Dictionary, path: String) -> Array:
	var errs: Array = []
	if spec.has("turns") and not (spec["turns"] is int or spec["turns"] is float):
		errs.append("%s.turns: must be a whole number (-1, or any negative, is permanent)" % path)
	if spec.has("ticks") and not (spec["ticks"] is int or spec["ticks"] is float):
		errs.append("%s.ticks: must be a whole number of engine ticks (-1, or any negative, is permanent)" % path)
	return errs

static func _validate_swap(spec: Dictionary, path: String, siblings) -> Array:
	var errs: Array = []
	# GROUNDED: the board has exactly four slots (MovesetComponent.display_abilities is a
	# hard [0..3] slice), and all 156 shipped ability_swap_effect calls replace slot 0-3.
	var slots: int = BlockSchema.LIMITS["visible_skill_slots"]
	var slot := int(spec.get("slot", -1))
	if slot < 0 or slot >= slots:
		errs.append("%s.slot: must be 0-%d (one of the %d visible skill slots)" % [path, slots - 1, slots])
	# Duration is author-controlled like every other effect (checked by _validate_duration);
	# ability_swap_effect takes a plain int and yoh1/yoh2/yoh3 each ship 20.
	# `into` may name a HIDDEN skill — that is what hidden skills are FOR, and the
	# shipped roster does exactly this (frieza5, yoruichi5 and kid6 are all hidden
	# swap-in targets). It still may not name another CHARACTER's skill: the index is
	# into this character's own moveset and nothing else is in scope.
	var max_abilities: int = BlockSchema.LIMITS["max_abilities"]
	var into := int(spec.get("into", -1))
	if into < 0 or into >= max_abilities:
		errs.append("%s.into: must name one of the character's own skills (0-%d)" % [path, max_abilities - 1])
		return errs
	if not siblings is Array:
		return errs                     # standalone validation: range check only
	var ordered := moveset_order(siblings)
	if into >= ordered.size():
		errs.append("%s.into: skill %d does not exist on this character" % [path, into])
		return errs
	var target_skill = ordered[into]
	if not target_skill is Dictionary:
		return errs
	# GROUNDED: Character.startup_passives finds passives by CLASS at battle start, so one
	# parked in a board slot would be a dead button. No shipped swap brings in a Passive.
	var tcls = target_skill.get("classes", [])
	if tcls is Array and "Passive" in tcls:
		errs.append("%s.into: cannot swap in a Passive — it never occupies a slot" % path)
	# Swap CHAINS are allowed, deliberately. cooler1 swaps in cooler5, and cooler5 re-applies
	# the identical Effect.ability_swap_effect(4, 0, user, 3) to extend itself — a shipped
	# self-chain that relies on swap.refresh to resolve the "race" the old ban claimed was
	# undefined. There is also nothing to recurse: a swapped-in skill only runs when a player
	# chooses to use it, so no chain length can loop inside one cast.
	return errs

# `skills` restricts a cost/cooldown/damage modifier to named abilities. Absent
# means "all of them", which is why null is accepted and an empty list is not:
# an empty list reads as a typo that would silently widen the effect. The size bound is
# max_abilities rather than a number of its own — a modifier must be able to name every
# skill its character has, and tying it to the ability count is the only bound that can
# never come up short.
static func _validate_named_skills(v, path: String) -> Array:
	if v == null:
		return []
	if not v is Array:
		return ["%s: must be a list of skill names" % path]
	if v.is_empty():
		return ["%s: must name at least one skill (omit the field for all skills)" % path]
	var cap: int = BlockSchema.LIMITS["max_abilities"]
	if v.size() > cap:
		return ["%s: at most %d skill names" % [path, cap]]
	for s in v:
		if str(s).strip_edges().is_empty():
			return ["%s: skill names must not be blank" % path]
	return []

# A damage_boost's include_types/exclude_types — a list of DAMAGE_TYPE names (the factory's
# class_targets / exclusion_targets, which get_true_damage compares against a hit's damage_type).
# Absent (null) is legal and means "no type filter" — today's byte-for-byte behaviour — so it is only
# rejected when present-but-malformed. An EMPTY list is rejected for the same reason _validate_named_skills
# rejects one: it reads as a typo that changes nothing, and an author who wrote a filter meant to name a
# type. Each entry must be a real BlockSchema.DAMAGE_TYPES member, the same whitelist damage_type_id maps.
static func _validate_damage_type_list(v, path: String) -> Array:
	if v == null:
		return []
	if not v is Array:
		return ["%s: must be a list of damage-type names (%s)" % [path, ", ".join(BlockSchema.DAMAGE_TYPES)]]
	if v.is_empty():
		return ["%s: name at least one damage type, or omit the field for no type filter" % path]
	var errs: Array = []
	for t in v:
		if not str(t) in BlockSchema.DAMAGE_TYPES:
			errs.append("%s: unknown damage type '%s' (must be one of %s)" % [path, str(t), ", ".join(BlockSchema.DAMAGE_TYPES)])
	return errs

# A selector in one of a CONDITION's slots (`on`, `of`, `vs`).
#
# BOTH of the other two selector lists get a PLACEMENT message rather than "unknown selector", and
# for the same reason _validate_block gives one: the name is real and spelled correctly, so "unknown
# selector 'holder'" sends the author hunting a typo that is not there. The filtered ones have said
# where they belong since they were added; the payload ones were still answering "unknown", which is
# the worse half of the same error on the more confusing case — `holder` is legal two lines above
# inside the payload the author is probably looking at.
static func _validate_cond_selector(v, path: String, field: String) -> Array:
	# GUARD 3 (PHASE F) — a selector OBJECT (pool/where/pick) is legal ONLY as a block's `to` (or the
	# ability target), NEVER inside a condition's on/of/vs. Nesting one would need a condition of its
	# own to resolve — the exact infinite regress the FILTERED_SELECTORS keep-out already names. This
	# reconciles the object explicitly with that keep-out so the two rules cannot drift apart.
	if v is Dictionary:
		return ["%s.%s: a selector object (pool/where/pick) belongs on a block's 'to', not inside a condition — a condition slot takes a plain selector ('target', 'user', or a pool), or the object would need a condition of its own to resolve (infinite regress)" % [path, field]]
	var s := str(v)
	if BlockSchema.SELECTORS.has(s):
		return []
	if BlockSchema.FILTERED_SELECTORS.has(s):
		return ["%s.%s: '%s' picks targets BY a condition, so it cannot be used inside one — use it as the block's 'to'" % [path, field, s]]
	if BlockSchema.is_payload_selector(s):
		return ["%s.%s: '%s' (%s) addresses the event a trigger or counter just watched, so it belongs in a payload block's 'to' — a condition slot takes a plain selector ('target', 'user', or a pool)" % [path, field, s, str(BlockSchema.PAYLOAD_SELECTORS[s])]]
	# A Layer-2 POOL name (main_target / enemies / dead_allies / ...) that is not also a plain selector.
	# It belongs in a block's `to` as {"pool": "<name>"}, not in a condition. `dead_allies` is the one
	# that motivates the explicit message: a usability check (`requires`) and a block `when` are both
	# evaluated with NO target chosen — there is no dead target during a usability check, so the pool
	# would name nobody. Say so rather than "unknown selector", which sends the author hunting a typo.
	if BlockSchema.POOLS.has(s):
		return ["%s.%s: '%s' is a target pool, not a condition selector — use it in a block's 'to' as {\"pool\": \"%s\"}. (A usability check runs before any target is chosen, so a pool like 'dead_allies' would name nobody here.)" % [path, field, s, s]]
	return ["%s.%s: unknown selector '%s'" % [path, field, s]]

static func _validate_condition(c, path: String, in_payload := false, event_where := "") -> Array:
	if not c is Dictionary:
		return ["%s: condition must be an object" % path]
	var errs: Array = []
	var key := str(c.get("cond", ""))
	if not BlockSchema.CONDITIONS.has(key):
		return ["%s: unknown condition '%s'" % [path, key]]
	var allowed := (BlockSchema.CONDITIONS[key]["args"] as Array).duplicate()
	allowed.append("cond")
	for k in c.keys():
		if not str(k) in allowed:
			errs.append("%s: unexpected field '%s' for condition '%s'" % [path, str(k), key])
	# A condition's own selector slots take PLAIN selectors only. A condition-filtered one
	# here would need a condition of its own to resolve, which is an infinite regress —
	# so it gets a message that says what to do instead rather than "unknown selector".
	if c.has("on"):
		errs.append_array(_validate_cond_selector(c["on"], path, "on"))
	if key in ["has_effect", "not_has_effect", "stacks_at_least"]:
		errs.append_array(_validate_presence(c, key, path))
	if key == "chance":
		# GROUNDED: battle.roll(1, 100), so a percentage cannot mean anything above 100, and
		# rejecting 0 catches the typo that would make the guarded block permanently dead.
		var p := int(c.get("percent", -1))
		if p < 1 or p > 100:
			errs.append("%s.percent: must be 1-100" % path)
	if key == "energy_at_least":
		# `of` names any member of the team whose pool is read (energy is a team resource); a PLAIN
		# selector, like every condition slot, so a filtered/object one is rejected by the shared helper.
		if c.has("of"):
			errs.append_array(_validate_cond_selector(c["of"], path, "of"))
		# The threshold. >= 0 (a pool never goes negative, so a negative threshold is always-true dead
		# weight); ceiling is the shared sanity clamp.
		var ev = c.get("value", null)
		if ev == null:
			errs.append("%s.value: name the amount of energy to require" % path)
		elif not (ev is int or ev is float):
			errs.append("%s.value: must be a number" % path)
		elif int(ev) < 0 or int(ev) > BlockSchema.LIMITS["max_amount"]:
			errs.append("%s.value: must be 0-%d" % [path, BlockSchema.LIMITS["max_amount"]])
	if key == "cost_color_at_least":
		# The colour must be one the cost pool actually holds (Random included — that is the whole
		# point of the shipped idiom). energy_colour_id maps these to Energy.Type.
		if not str(c.get("colour", "")) in BlockSchema.COST_COLOURS:
			errs.append("%s.colour: must be one of %s" % [path, ", ".join(BlockSchema.COST_COLOURS)])
		# The threshold. >= 1: a cost is never negative and "costs at least 0 of anything" is always
		# true — dead weight, the inert-control trap. Ceiling is the shared sanity clamp.
		var cv = c.get("value", null)
		if cv == null:
			errs.append("%s.value: name how much of that colour the skill must cost" % path)
		elif not (cv is int or cv is float):
			errs.append("%s.value: must be a number" % path)
		elif int(cv) < 1 or int(cv) > BlockSchema.LIMITS["max_amount"]:
			errs.append("%s.value: must be 1-%d — a threshold of 0 is always true (a cost is never negative)" % [path, BlockSchema.LIMITS["max_amount"]])
	if key == "compare":
		for sel_field in ["of", "vs"]:
			if c.has(sel_field):
				errs.append_array(_validate_cond_selector(c[sel_field], path, sel_field))
		# The value is EITHER a string enum OR a reading OBJECT (the same node a scaling amount's `each`
		# takes). alive_count MOVED into READINGS but stays legal here as a bare string for back-compat —
		# see BlockSchema.is_reading_name. A reading value folds the whole selection to ONE number, so it
		# behaves exactly like alive_count did: pair op only, compared against a `than` number.
		var value = c.get("value", "")
		var value_is_reading: bool = value is Dictionary
		if value_is_reading:
			errs.append_array(_validate_reading(value, path + ".value", in_payload, event_where))
		elif not str(value) in BlockSchema.COMPARE_VALUES and not BlockSchema.is_reading_name(value):
			errs.append("%s.value: must be one of %s, alive_count, or a reading" % [path, ", ".join(BlockSchema.COMPARE_VALUES)])
		# A single-number value (a reading object, or the alive_count string) has nothing to fold and no
		# second character to compare against — only a `than` number.
		var single_number: bool = value_is_reading or BlockSchema.is_reading_name(value)
		var op := str(c.get("op", ""))
		var group_op: bool = op in BlockSchema.COMPARE_GROUP_OPS
		if not group_op and not op in BlockSchema.COMPARE_PAIR_OPS:
			errs.append("%s.op: must be one of all_equal, any_differ, gt, lt, eq" % path)
		elif group_op:
			# all_equal/any_differ fold a LIST of per-character readings to one bool. A single-number
			# value is already folded, so there is nothing to fold and the pair would read "true" forever.
			if single_number:
				errs.append("%s: that value is a single number — use gt/lt/eq, not %s" % [path, op])
			if c.has("than") or c.has("vs"):
				errs.append("%s: %s compares the group with itself; drop 'than'/'vs'" % [path, op])
		else:
			# A single-number value compares against a `than` NUMBER, never a `vs` selector (there is no
			# per-character reading to line up against another character's).
			if single_number and c.has("vs"):
				errs.append("%s: that value is a single number — compare it with a 'than' number, not a 'vs' selector" % path)
			if not single_number and c.has("than") and c.has("vs"):
				errs.append("%s: give either 'than' (a number) or 'vs' (a selector), not both" % path)
			if not c.has("than") and not c.has("vs"):
				errs.append("%s: %s needs a 'than' number or a 'vs' selector" % [path, op])
			if c.has("than") and not (c["than"] is int or c["than"] is float):
				errs.append("%s.than: must be a number" % path)
	return errs

# The presence pair, `.effect` and `.by`. Both optional; with neither, these conditions read
# exactly as they always did (any type, anybody's copy) so no saved character changes meaning.
#
# THE ONE HARD RULE is that `by` needs `effect`, and it is the ENGINE'S rule rather than a design
# preference: effect_storage_component.has_effect(name, type, user) matches all three at once
# (:67-71) and there is no name+user-without-type entry point anywhere to fall back on. Accepting
# `by` alone would leave a control that renders, validates, and filters nothing — so it says which
# field to add rather than "unknown".
#
# `stacks_at_least` is EXEMPT from that rule, because its type is not absent: it defaulted to MARK
# long before this field existed and still does, so "my own mark" is answerable there without the
# author naming a type.
static func _validate_presence(c: Dictionary, key: String, path: String) -> Array:
	var errs: Array = []
	if c.has("effect") and not str(c["effect"]) in BlockSchema.immunity_effects():
		errs.append("%s.effect: '%s' is not an effect type (omit it to match any type carrying that name)" % [path, str(c["effect"])])
	if not c.has("by"):
		return errs
	if not str(c["by"]) in BlockSchema.PRESENCE_BY:
		errs.append("%s.by: must be 'any' (anybody's copy) or 'mine' (only the one this skill's user applied)" % path)
	elif str(c["by"]) == "mine" and not c.has("effect") and key != "stacks_at_least":
		errs.append("%s.by: 'mine' also needs an effect type — the engine only matches a caster together with a type, so on its own it would quietly go back to matching anybody's" % path)
	return errs

# A signed magnitude: POSITIVE taxes the target (+1 Random to cast, +1 turn of
# cooldown), NEGATIVE discounts it. 0 is rejected rather than accepted as a no-op —
# an author who typed it meant one direction or the other, and a silently inert
# effect is the worst thing to hand back. The magnitude is the same symmetric sanity
# envelope _validate_amount uses, and it is the one BlockRunner._signed_amount clamps to,
# so the two cannot disagree. It used to be -2..2, which mercury1 —
# Effect.cooldown_mod(-3, 3, ["Shine Aqua Illusion"]), the very ability that motivated
# allowing negatives at all — already violated.
static func _validate_signed_amount(v, path: String) -> Array:
	if v == null:
		return ["%s: required" % path]
	if not (v is int or v is float):
		return ["%s: must be a number" % path]
	var n := int(v)
	if n == 0:
		return ["%s: must not be 0 — use a positive number to increase, negative to reduce" % path]
	var cap: int = BlockSchema.LIMITS["max_amount"]
	if n < -cap or n > cap:
		return ["%s: must be %d..%d (negative reduces, positive increases)" % [path, -cap, cap]]
	return []

# An UNSIGNED size (damage, healing, shield, ...). The floor at 0 is grounded: a negative
# would invert the operation inside Character.resolve_damage / resolve_healing. The ceiling
# is a pure sanity clamp — the signed kinds bypass this via SIGNED_AMOUNT_KINDS.
static func _validate_amount(v, path: String, allow_scaling := false, in_payload := false, event_where := "") -> Array:
	# A SCALING amount is an object {base, per, cap, each} — base + per*count, capped. It is legal
	# ONLY on the damage/heal ops (allow_scaling). An EFFECT'S own `amount` stays a flat number,
	# because the per-row simple-effect guards (_validate_simple_limits) read it as an int and a
	# scaling one there would slip past its named abuse case.
	if v is Dictionary:
		if not allow_scaling:
			return ["%s: must be a number — a scaling amount is only allowed on a damage or heal block" % path]
		return _validate_scaling_amount(v, path, in_payload, event_where)
	if v == null:
		return ["%s: required" % path]
	if not (v is int or v is float):
		return ["%s: must be a number" % path]
	var n := int(v)
	if n < 0 or n > BlockSchema.LIMITS["max_amount"]:
		return ["%s: must be 0-%d" % [path, BlockSchema.LIMITS["max_amount"]]]
	return []

# A scaling amount: (base + per*count) / div, then a MANDATORY cap. `each` is the reading node; `div`
# is the optional fraction divisor (default 1).
static func _validate_scaling_amount(v: Dictionary, path: String, in_payload := false, event_where := "") -> Array:
	var errs: Array = []
	var cap_i: int = BlockSchema.LIMITS["max_amount"]
	# base and per are unsigned magnitudes in the SAME 0..max_amount envelope a flat amount answers to.
	for f in ["base", "per"]:
		if not v.has(f):
			errs.append("%s.%s: required — a scaling amount is base + per * count" % [path, f])
		elif not (v[f] is int or v[f] is float):
			errs.append("%s.%s: must be a number" % [path, f])
		elif int(v[f]) < 0 or int(v[f]) > cap_i:
			errs.append("%s.%s: must be 0-%d" % [path, f, cap_i])
	# cap is MANDATORY. ABUSE: without it, per*count is bounded only by the board — a per-stack term
	# over a stacking mark with no ceiling is an unbounded ramp the per-block max_amount clamp only
	# catches AFTER it has already scaled past every hand-written skill. Naming the ceiling is the guard.
	if not v.has("cap"):
		errs.append("%s.cap: required — a per-term must name its ceiling, or the scaling is unbounded" % path)
	elif not (v["cap"] is int or v["cap"] is float):
		errs.append("%s.cap: must be a number" % path)
	elif int(v["cap"]) < 1 or int(v["cap"]) > cap_i:
		errs.append("%s.cap: must be 1-%d" % [path, cap_i])
	# div (optional, default 1) turns base + per*count into a clean FRACTION of itself — the piece that
	# makes "reflect 50%" (per:1, div:2), "25%" (div:4) or "150%" (per:3, div:2) buildable at all, since
	# per is an int and per:0.5 floored to 0. ABUSE: a div of 0 is a divide-by-zero crash in _amount, and
	# a negative div flips an unsigned amount's sign. Reject <1 BY NAME — this is the crash/sign guard, and
	# per the no-invented-caps rule there is deliberately NO upper bound (an author picks any ratio).
	if v.has("div"):
		if not (v["div"] is int or v["div"] is float):
			errs.append("%s.div: must be a number" % path)
		elif int(v["div"]) < 1:
			errs.append("%s.div: must be at least 1 — it divides base + per * count, so 0 divides by zero and a negative flips the sign (use div:2 for half, div:4 for a quarter)" % path)
	errs.append_array(_validate_reading(v.get("each", null), path + ".each", in_payload, event_where))
	# SECURITY BOUNDARY, exactly as blocks/effects/conditions: an unknown key is a control a future
	# runner branch might read, so the shape is exhaustive rather than indicative.
	for k in v.keys():
		if not str(k) in ["base", "per", "cap", "div", "each"]:
			errs.append("%s: unexpected field '%s' in a scaling amount" % [path, str(k)])
	return errs

# A reading node {read, of, name, effect} — the closed enum that mounts as a scaling amount's `each`,
# a compare value, and a repeat times. `read` is checked against the closed BlockSchema.READINGS.
static func _validate_reading(node, path: String, in_payload := false, event_where := "") -> Array:
	if not node is Dictionary:
		return ["%s: a reading is required — {read, of, name, effect}" % path]
	var errs: Array = []
	var read := str(node.get("read", ""))
	if not read in BlockSchema.READINGS:
		errs.append("%s.read: must be one of %s" % [path, ", ".join(BlockSchema.READINGS)])
	# `event` reads QueryContext.value, the magnitude the firing event carried. That value is 0 on every
	# hook whose dispatcher does not thread a number into it — the PER-HOOK LIE hazard: a card that says
	# "reflect the amount I just took" doing nothing. It is legal ONLY inside a payload on a hook in
	# BlockSchema.EVENT_TRIGGERS (the damage-dealt / damage-received / healing-given family). Two reject
	# shapes, so the message points where it should:
	#   * event_where == ""  — not in any payload; there is no firing event at all (the original case).
	#   * event_where names a hook/context NOT in EVENT_TRIGGERS — a counter payload, a recurring/turn/
	#     death payload, or a magnitude-less trigger (on_stunned, on_skill_used, ...). The event fires,
	#     but carries no number, so `event` would silently read 0 there.
	if read == "event" and not event_where in BlockSchema.EVENT_TRIGGERS:
		if event_where == "":
			errs.append("%s.read: 'event' reads how much the triggering event dealt (damage taken/dealt, healing given), so it only means something inside a trigger, counter or recurring payload's blocks — out here there is no event to read; use a board reading (%s) instead" % [path, ", ".join(BlockSchema.EFFECT_READS + ["hp", "missing_hp", "alive_count", "energy"])])
		else:
			errs.append("%s.read: 'event' has no magnitude on '%s' — that hook's dispatcher threads no damage/healing value into the context, so 'event' would silently read 0. Read it only where a number rides the event: %s" % [path, event_where, ", ".join(BlockSchema.EVENT_TRIGGERS)])
	# `of` is a PLAIN selector: a filtered/payload one would need a condition of its own to resolve
	# (an infinite regress), exactly as a compare's `of` does. Optional — absent reads all_enemies.
	if node.has("of"):
		errs.append_array(_validate_cond_selector(node["of"], path, "of"))
	# `dead_count` folds a whole TEAM's fallen roster to one number, so its `of` must NAME a team, not a
	# target — exactly the three POOL scopes (all_allies / other_allies / all_enemies). A singular `of`
	# ('target', 'user', a payload/filtered selector, or an absent one defaulting to a single head) would
	# ask this read to count the dead of ONE character: it could only ever answer 0 or 1, a per-hook lie
	# for a scaling amount that means "per fallen ally". Require the pool by name, distinct from every
	# other read (which happily takes a single-target `of`).
	if read == "dead_count" and not str(node.get("of", "")) in BlockSchema.POOL_SELECTORS:
		errs.append("%s.of: 'dead_count' counts a whole team's fallen members, so 'of' must name a team pool (%s) — a single target or payload selector could only ever count 0 or 1 dead, which is a per-hook lie" % [path, ", ".join(BlockSchema.POOL_SELECTORS)])
	# `effect` (optional) narrows the effect-enumerating reads to one type, range-checked against the
	# SAME EffectType-derived list remove/adjust/effect_immunity share so the vocabularies cannot drift.
	if node.has("effect") and not str(node["effect"]) in BlockSchema.immunity_effects():
		errs.append("%s.effect: '%s' is not an effect type (omit it to match any type)" % [path, str(node["effect"])])
	for k in node.keys():
		if not str(k) in ["read", "of", "name", "effect"]:
			errs.append("%s: unexpected field '%s' in a reading" % [path, str(k)])
	return errs

# `remove`.stacks is EITHER the BlockSchema.REMOVE_ALL sentinel (take the whole effect) or a
# positive count of stacks to spend. The ceiling is the SAME LIMITS.max_stacks a mark's own
# `max` is checked against — borrowing it rather than writing a second number is what keeps the
# two from disagreeing about how tall a stack may get. Spending MORE than the effect currently
# holds is deliberately legal (the runner just ends it), so this bounds the typo, not the intent.
# `adjust`'s three DELTA axes. At least one is required, and every one of them is a delta — there is
# no `set` axis to validate because there is no `set` axis at all (see the OPS row: a set form
# invites unbounded ramps, "set this mark to 99 stacks" reaching in one cast a number no amount of
# stacking could earn). The unknown-field rejection above is what makes that omission enforceable.
#
# Each bound BORROWS the LIMIT its axis already answers to rather than inventing a fourth number:
# turns -> max_turn_delta (a ±N CHANGE in duration, the same signed-delta envelope the cooldown op
# uses — not the removed absolute-duration cap), stacks -> max_stacks, mag -> max_amount. 0 is rejected
# on the same reasoning
# _validate_signed_amount rejects it: an author who typed it meant one direction or the other, and a
# silently inert block is the worst thing to hand back.
#
# Nothing bounds the ACCUMULATED value across casts, deliberately. "Extend it by one more turn"
# every turn is precisely what the corpus does (character/toji.gd:118, abilities/uzui5.gd:27), and
# capping the total would be a rule the game does not have.
static func _validate_adjust_deltas(b: Dictionary, path: String) -> Array:
	var errs: Array = []
	var axes := {
		"turns": BlockSchema.LIMITS["max_turn_delta"],
		"stacks": BlockSchema.LIMITS["max_stacks"],
		"mag": BlockSchema.LIMITS["max_amount"],
	}
	var given := 0
	for axis in axes.keys():
		if not b.has(axis):
			continue
		var v = b[axis]
		if not (v is int or v is float):
			errs.append("%s.%s: must be a whole number (negative reduces, positive increases)" % [path, axis])
			continue
		var n := int(v)
		if n == 0:
			errs.append("%s.%s: must not be 0 — use a positive number to increase, negative to reduce" % [path, axis])
			continue
		var cap: int = axes[axis]
		if n < -cap or n > cap:
			errs.append("%s.%s: must be %d..%d" % [path, axis, -cap, cap])
			continue
		given += 1
	if given == 0 and errs.is_empty():
		errs.append("%s: adjust needs at least one of 'turns', 'stacks' or 'mag' to change — each is a change BY that much, not a value to set" % path)
	return errs

# Does this block list carry (anywhere, recursively) a damage/heal whose `amount` is a SCALING
# object? The product bound uses it to catch the one combination that scales in two board
# dimensions at once — a reading times around a reading amount.
static func _body_has_scaling_amount(blocks) -> bool:
	if not blocks is Array:
		return false
	for b in blocks:
		if not b is Dictionary:
			continue
		if str(b.get("op", "")) in ["damage", "heal"] and b.get("amount", null) is Dictionary:
			return true
		if b.has("blocks") and _body_has_scaling_amount(b["blocks"]):
			return true
		if b.get("else", null) is Array and _body_has_scaling_amount(b["else"]):
			return true
	return false

# `repeat`.times. Bounded INDEPENDENTLY of max_amount, because a repetition is not a magnitude:
# every repetition is a separate resolution that re-pays the minimum-damage floor, re-tests damage
# reduction and re-fires every receive-trigger on the target — so N repeats of X are strictly
# stronger than one hit of N*X, and a number that is merely large as damage is a hot loop here.
# _count_blocks bounds the PRODUCT (times x body) against the 40-block ceiling on top of this.
static func _validate_repeat_times(b: Dictionary, path: String, in_payload := false, event_where := "") -> Array:
	var cap: int = BlockSchema.LIMITS["max_repeat_times"]
	var v = b.get("times", null)
	# A reading OBJECT is a scaling repetition count (Phase B's constant form takes a reading for free).
	# It is clamped to max_repeat_times at runtime; the quadratic combination with a scaling amount is
	# refused by the product bound in the repeat arm above.
	if v is Dictionary:
		return _validate_reading(v, path + ".times", in_payload, event_where)
	if v == null:
		return ["%s.times: how many times to run these blocks (1-%d)" % [path, cap]]
	if not (v is int or v is float):
		return ["%s.times: must be a whole number 1-%d" % [path, cap]]
	var n := int(v)
	if n < 1 or n > cap:
		# 0 is called out separately: it is not "too few", it is a branch that never runs, and an
		# author who typed it has written a block list they will never see fire.
		if n <= 0:
			return ["%s.times: must be at least 1 — 0 means these blocks never run at all" % path]
		return ["%s.times: must be 1-%d — each repetition is a separate hit (shields, damage reduction, the damage floor and every reactive trigger all apply again), so this is not the same knob as a bigger amount" % [path, cap]]
	return []

static func _validate_remove_stacks(v, path: String) -> Array:
	var cap: int = BlockSchema.LIMITS["max_stacks"]
	var shape := "%s.stacks: must be '%s' or a whole number 1-%d" % [path, BlockSchema.REMOVE_ALL, cap]
	if v is String:
		return [] if str(v) == BlockSchema.REMOVE_ALL else [shape]
	if not (v is int or v is float):
		return [shape]
	var n := int(v)
	return [] if n >= 1 and n <= cap else [shape]
