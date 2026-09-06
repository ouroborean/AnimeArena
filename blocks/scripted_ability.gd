extends Ability
class_name ScriptedAbility

# ============================================================================
# An Ability whose behaviour comes from DATA (a validated block tree) instead of
# hand-written GDScript. One class backs every authored skill; the block tree is
# handed to it at construction by Ability.from_database.
#
# It fills in the three hooks the engine and the bot need, all derived from the
# same block tree so an author never writes them by hand:
#   execute()         -> BlockRunner walks the blocks
#   split_desc()      -> generated prose (34% of hand-written ability code is
#                        description; authored content must not owe that debt)
#   custom_behavior() -> bot scoring hints (942 of 997 existing abilities define
#                        these; without them an authored character is invisible
#                        to the v3 bot policy and never gets used by AI opponents)
#   target()          -> chosen from the authored `target` field
# ============================================================================

var blocks: Array = []
var target_mode: String = "enemy"     # enemy | ally | self | all_enemies | all_allies | everyone
# PHASE F — the parsed Layer-1 ELIGIBILITY object. A bare string `target` leaves these at their
# defaults and `_target_is_object` false (the legacy path). An object `target` fills them: `mode` is
# the SIDE (enemy/ally/self/everyone), `shape` the fan-out (one/all), `only` the per-candidate
# predicate list, `pick`/`measure` the extremal restriction (hisoka6), and the three bools the
# per-ability overrides. exclude_self IS `selfless` (AuthoredCharacter mounts it from here).
var _target_is_object: bool = false
var target_shape: String = "one"
var target_only: Array = []
var target_pick: String = "all"
var target_measure: String = "hp"
var target_bypass: bool = false        # per-ability invuln bypass, ORed onto the Bypassing class
# GAP-2 — the PER-CANDIDATE invuln bypass. `target_bypass` is all-or-nothing (bypass every candidate or
# none); this is a CONDITION (or null when absent) evaluated once per candidate, so a skill can bypass
# invulnerability against an enemy ONLY WHEN the condition holds for that enemy (nonon3: "marked by
# Overture Barrage"). null/absent leaves targeting byte-identical to the single precomputed value.
var target_bypass_when = null
var target_exclude_self: bool = false  # == selfless
var target_include_dead: bool = false  # flag dead allies too (jeanne4's revive)
var author_desc: String = ""          # optional author-written flavour line
var requires: Array = []              # conditions gating usability (extra_usable)
var icon_slot: String = ""            # AuthoredAssets slot holding this skill's art ("" = none)
# "" | "control" | "channel" — see BlockSchema.CHANNEL_MODES. A skill that declares one plants a
# cancel holder over everything it applied, so the whole cast ends together when the user is
# interrupted.
var channel_mode: String = ""
# 0 = unlimited. When > 0 the skill may be cast at most this many times per MATCH: each cast bumps a
# permanent charge MARK on the user, and extra_usable refuses the skill once the count is reached. The
# mark is system + display_system (cleanse-proof but still visible — the opponent is entitled to see
# "N uses per match") and remove_on_death:false + cleansable:false, so neither a buff-strip refunds a
# charge nor a revive resets the counter. See _tick_use_charge / _uses_mark_name.
var max_uses: int = 0

func configure(spec: Dictionary) -> void:
	blocks = spec.get("blocks", [])
	_parse_target(spec.get("target", "enemy"))
	author_desc = str(spec.get("text", ""))
	requires = spec.get("requires", [])
	icon_slot = str(spec.get("icon", ""))
	channel_mode = str(spec.get("channel", ""))
	max_uses = int(spec.get("max_uses", 0))

# String-or-object `target`. A string keeps the legacy six-mode path (target_mode is the whole
# story); an object splits mode/shape and carries the predicate half. exclude_self is written onto
# `selfless` here so the flag the engine's own allied-targeting reads is set from the object — the
# build paths default `selfless` to target_exclude_self.
func _parse_target(t) -> void:
	if t is Dictionary:
		_target_is_object = true
		target_mode = str(t.get("mode", "enemy"))
		target_shape = str(t.get("shape", "one"))
		target_only = t.get("only", []) if t.get("only", []) is Array else []
		target_pick = str(t.get("pick", "all"))
		target_measure = str(t.get("measure", "hp"))
		target_bypass = bool(t.get("bypass_invuln", false))
		# bypass_when is a CONDITION dict or absent. Stored raw for per-candidate eval in _target_object;
		# a non-Dictionary (only reachable from a hand-edited file — the validator rejects it) is dropped
		# to null so the eval is skipped rather than crashing on a malformed predicate mid-turn.
		var pw = t.get("bypass_when", null)
		target_bypass_when = pw if pw is Dictionary else null
		target_exclude_self = bool(t.get("exclude_self", false))
		target_include_dead = bool(t.get("include_dead", false))
		if target_exclude_self:
			selfless = true
	else:
		_target_is_object = false
		target_mode = str(t)

# --- execution --------------------------------------------------------------
func execute(user, battle):
	var runner := BlockRunner.new(self, battle, user)
	# ONLY HERE. A trigger/counter payload builds its own BlockRunner and never calls this, which
	# is what stops a channelled skill from re-planting its cancel holder every time one of its own
	# triggers fires — the payload runs turns later and is not part of the cast.
	runner.set_channel(channel_mode)
	runner.run(blocks)
	# A `max_uses` charge is spent on the CAST, after the blocks resolve — a skill that was cast is a
	# skill that was used, whether or not it found a target. extra_usable already refused it past the
	# limit, so this only ever counts up.
	_tick_use_charge(user, battle)

# The per-ability, per-user charge counter for max_uses. A distinct name (not the ability's own, which
# a `mark` block would collide with) keyed on the user, so has_effect(name, MARK, user) finds exactly
# this counter.
func _uses_mark_name() -> String:
	return "Uses — " + ability_name

# Bump the charge counter, planting it on first use. The four survival flags are the contract: system
# + display_system keep it cleanse-proof yet visible, remove_on_death:false survives a death (so a
# revive cannot reset it), cleansable:false is the belt to system's braces (a buff-strip must not
# refund a charge). Incrementing an existing counter writes `stacks` directly + emits effect_updated
# (the `adjust` op's own idiom, block_runner.gd:963) — re-applying through add_allied_effect would
# REPLACE a non-stackable mark and reset the count to 1.
func _tick_use_charge(user, battle) -> void:
	if max_uses <= 0 or user == null or battle == null:
		return
	var key := _uses_mark_name()
	var existing = user.has_effect(key, EffectType.Type.MARK, user)
	if existing != null and is_instance_valid(existing):
		existing.stacks = int(existing.stacks) + 1
		existing.effect_updated.emit(existing)
		return
	var context = QueryContext.from_game_state(user, battle)
	var m = Effect.mark(-1, "Uses of " + ability_name + " this match.")
	m.name_override = key
	m.stacks = 1
	m.system = true
	m.display_system = true
	m.remove_on_death = false
	m.cleansable = false
	m.set_source(self)
	Character.add_allied_effect(context, user, user, m, true)

# Usage gating. Authors express "this skill needs X" with the same condition
# vocabulary the `when` guard uses, so there is nothing new to learn and nothing
# new to validate. Every condition must hold for the skill to be selectable.
func extra_usable(user):
	# The max_uses gate is checked BEFORE the `requires` conditions and independently of them — a
	# spent-out skill is unusable even with no `requires` at all. Read the charge counter's stacks
	# (uses so far); once it reaches the ceiling the skill is refused.
	if max_uses > 0 and user != null:
		var mk = user.has_effect(_uses_mark_name(), EffectType.Type.MARK, user)
		var spent: int = mk.stack_count() if mk != null else 0
		if spent >= max_uses:
			return false
	if requires.is_empty():
		return true
	if user == null or user.battle == null:
		return true
	var runner := BlockRunner.new(self, user.battle, user)
	for cond in requires:
		if not runner.check_condition_public(cond):
			return false
	return true

# --- targeting --------------------------------------------------------------
func target(user, battle):
	# The "Bypassing" CLASS is how a skill declares that it ignores invulnerability, and the
	# helpers take it as their THIRD positional argument — that is how a shipped kit spells it
	# (abilities/nimaiya1.gd:56 documents the exact call). Passing it here is what makes the
	# class mean something for authored content: without it a skill could tick Bypassing, print
	# the chip on its card, and still be unable to click an invulnerable enemy.
	# default_self_target_function is deliberately not given it — it already passes `true` to
	# check_allied_target internally (ability_component.gd:873), so a self-cast is never gated.
	var bypassing: bool = bool(classes.get("Bypassing", false))
	# PHASE F LAYER 1 — the eligibility OBJECT. Everything downstream keys off the flags target()
	# sets (counters, reflect, taunt, blind, _drop_invuln_targets, AoE expansion, the client's "no
	# valid targets" refusal), so an object-driven filtered set enters the SAME interception pipeline
	# a hand-written override's does — which is the payoff a block-level `to` filter could never
	# reach, because it resolves after the pipeline is over.
	if _target_is_object:
		_target_object(user, battle, bypassing)
		return
	match target_mode:
		"ally", "all_allies":
			default_allied_target_function(user, battle, bypassing)
		"self":
			default_self_target_function(user, battle)
		"everyone":
			# TargetType.ALL means every valid target on the board, so flag BOTH sides —
			# the hostile pass alone would have made this identical to all_enemies.
			default_hostile_target_function(user, battle, bypassing)
			default_allied_target_function(user, battle, bypassing)
		_:
			default_hostile_target_function(user, battle, bypassing)

# The eligibility object's flagging pass. Walk every character, keep the ones every `only` predicate
# holds for (per-candidate subject — the same binding a block `where` uses), optionally narrow to the
# extremal-`measure` candidate(s) for pick:lowest/highest (ties included, hisoka6's shape), then flag
# the survivors on the object's SIDE through the same two helpers the 64 shipped overrides call.
# `bypass_invuln` is the per-ability override, ORed onto the Bypassing class (the class already
# reaches here); it is purely additive, matching "the object only adds a per-ability override".
# `bypass_when` is the PER-CANDIDATE override on top of that: computed inside the flag loop below so a
# skill can reach through invulnerability for one candidate and not another (GAP-2 — nonon3's mark-gated
# bypass). Absent, the flag value is the same class_bypassing-or-target_bypass for every candidate.
func _target_object(user, battle, class_bypassing: bool) -> void:
	if target_mode == "self":
		default_self_target_function(user, battle)
		return
	var context = QueryContext.from_game_state(user, battle)
	var runner := BlockRunner.new(self, battle, user)
	var survivors: Array = []
	for c in battle.all_characters():
		if c.banished:
			continue
		if not _side_candidate(user, c):
			continue
		var ok := true
		for cond in target_only:
			if not runner.check_condition_public(cond, c):
				ok = false
				break
		if ok:
			survivors.append(c)
	survivors = _eligibility_pick(survivors, runner)
	# The all-or-nothing part of the bypass is computed ONCE (the Bypassing class ORed with the
	# per-ability bypass_invuln override) — unchanged from before bypass_when existed. Then, per
	# candidate, bypass_when can add a conditional reach: it is evaluated with `c` as the subject
	# through the SAME check_condition_public the `only` predicates use above, so "bypass invuln for
	# THIS enemy iff it is marked" is expressible without touching the flag order or the pick measure.
	# When target_bypass_when is null this is byte-identical to passing base_bypass to every candidate.
	var base_bypass: bool = class_bypassing or target_bypass
	for c in survivors:
		var cand_bypass: bool = base_bypass or (target_bypass_when != null and runner.check_condition_public(target_bypass_when, c))
		_flag_candidate(user, c, context, cand_bypass)

# Is this candidate on the SIDE the object targets at all? The `only` predicates and the pick measure
# are only meaningful over the side that could be flagged (hisoka6's minimum is over ENEMIES, not the
# whole board), so this gate runs before both.
func _side_candidate(user, c) -> bool:
	var allied: bool = not user.is_hostile(c)
	if allied:
		if not target_mode in ["ally", "everyone"]:
			return false
		if (target_exclude_self or selfless) and c == user:
			return false
		return true
	return target_mode in ["enemy", "everyone"]

# pick:lowest/highest RESTRICTS eligibility to the extremal LIVING candidate(s), ties included. all
# (the default) and random flag every survivor — a random eligibility set is barred by the validator
# for the same re-run reason `chance` is, so it never reaches here.
func _eligibility_pick(survivors: Array, runner) -> Array:
	if not (target_pick == "lowest" or target_pick == "highest"):
		return survivors
	var living: Array = []
	for c in survivors:
		if not (c.dead or c.banished):
			living.append(c)
	if living.is_empty():
		return survivors
	var best: int = runner.char_measure(living[0], target_measure)
	for c in living:
		var v: int = runner.char_measure(c, target_measure)
		if (target_pick == "lowest" and v < best) or (target_pick == "highest" and v > best):
			best = v
	var out: Array = []
	for c in living:
		if runner.char_measure(c, target_measure) == best:
			out.append(c)
	return out

# Flag one candidate the way its side is flagged. A LIVING candidate goes through the engine's own
# check_hostile_target / check_allied_target (the invuln / isolation / extra-targetable predicates,
# byte-identical to the shipped overrides). A DEAD, non-banished candidate is flagged directly with
# set_targeted() ONLY when include_dead is set — can_allied_target's is_alive clause would otherwise
# drop it, which is exactly why jeanne4 hand-flags dead allies for its revive.
func _flag_candidate(user, c, context, bypassing) -> void:
	var allied: bool = not user.is_hostile(c)
	if c.dead:
		if target_include_dead:
			c.set_targeted()
		return
	if allied:
		check_allied_target(user, c, context, bypassing)
	else:
		check_hostile_target(user, c, context, bypassing)

# --- generated description --------------------------------------------------
func describe(user):
	var parts: Array = []
	for seg in split_desc():
		parts.append(seg[0] if seg is Array else str(seg))
	return " ".join(parts) + ("" if parts.is_empty() else ".")

func split_desc():
	var out: Array = []
	if author_desc != "":
		out.append(author_desc)
	# PHASE F — the Layer-1 eligibility clause on the target line. `_describe_filter` already writes
	# exactly the "carrying the user's own Death Chaser" phrase the filtered selectors use; this folds
	# each `only` predicate (plus a pick / include_dead tail) into one "Can only be used on ..." line.
	if _target_is_object:
		var tl := _describe_target_eligibility()
		if tl != "":
			out.append([tl, Color.DIM_GRAY])
		# The per-candidate invuln bypass (GAP-2) is its OWN line, coloured like the other bypass/channel
		# clauses — it changes who the skill can CLICK (an invulnerable enemy the condition holds for), so
		# it is not folded into the DIM eligibility restriction. Empty when bypass_when is absent, so the
		# card is byte-for-byte what it showed before this field existed.
		var pl := _describe_target_bypass()
		if pl != "":
			out.append([pl, Color.CADET_BLUE])
	for req in requires:
		var r := _describe_condition(req)
		if r != "":
			out.append(["Requires: " + r.trim_prefix("if "), Color.DIM_GRAY])
	# The opponent is entitled to see the charge budget (the counter mark is display_system for the
	# same reason), so it prints on the card — one clause, the contract for the max_uses gate.
	if max_uses > 0:
		out.append(["Can be used %d time%s per match" % [max_uses, "" if max_uses == 1 else "s"], Color.DIM_GRAY])
	if classes.get("Passive", false):
		out.append(["Passive — active from the start of the battle", Color.AQUAMARINE])
	# The channel flag prints its BREAK CONDITION, not just its name. "Channeled" on a card tells a
	# player nothing they can act on; "ends if the user is stunned" tells them what to do about it,
	# and it is the only thing on the card that says the whole skill can be undone from outside.
	if channel_mode == "channel":
		out.append(["Channeled — everything this skill applies ends if the user is stunned, killed, banished, or uses another skill", Color.CADET_BLUE])
	elif channel_mode == "control":
		out.append(["Controlled — everything this skill applies ends if the user is stunned, killed or banished", Color.CADET_BLUE])
	for b in blocks:
		var line := _describe_block(b)
		if line != "":
			out.append(line)
	if out.is_empty():
		out.append("This skill has no effect yet.")
	return out

func _describe_block(b) -> String:
	var line := _describe_block_body(b)
	# `group` and `repeat` are bundles of other sentences, each of which already carried its own
	# clause — and neither op has a `bypassing` field of its own to print.
	if line == "" or not b is Dictionary or str(b.get("op", "")) in ["group", "repeat"]:
		return line
	return line + _describe_bypass(b)

# The per-block invulnerability override, printed ONLY when the author set it explicitly.
# The ability-level "Bypassing" class already shows as a chip on the skill card, so restating
# it on every line would be noise — but a block that DISAGREES with the skill's own declaration
# (or reaches through invuln on a skill that isn't Bypassing at all) is invisible to the player
# unless the sentence says so.
func _describe_bypass(b: Dictionary) -> String:
	var v = b.get("bypassing", null)
	if not v is bool:
		return ""
	return ", even through invulnerability" if v else ", but not through invulnerability"

func _describe_block_body(b) -> String:
	if not b is Dictionary:
		return ""
	var sel := str(b.get("to", "target"))
	var who := _describe_selector(sel)
	var cond := ""
	# With a condition-filtered selector the `when` is not a gate on the sentence — it is
	# part of WHO the sentence is about, so it is folded into the subject instead of being
	# printed as a leading "if ...," clause.
	if BlockSchema.FILTERED_SELECTORS.has(sel):
		who = _describe_filtered(sel, b.get("when", null))
	elif b.has("when"):
		cond = _describe_condition(b["when"]) + ", "
	match str(b.get("op", "")):
		"damage":
			var dt := str(b.get("damage_type", "NORMAL"))
			var dtxt := "" if dt == "NORMAL" else " " + dt.capitalize()
			var damt = b.get("amount", 0)
			if damt is Dictionary:
				return "%sDeals %d%s damage to %s, %s" % [_sentence_case(cond), int(damt.get("base", 0)), dtxt, who, _scaling_tail(damt)]
			return "%sDeals %d%s damage to %s" % [_sentence_case(cond), int(damt), dtxt, who]
		"heal":
			var hamt = b.get("amount", 0)
			if hamt is Dictionary:
				return "%sHeals %s for %d HP, %s" % [_sentence_case(cond), who, int(hamt.get("base", 0)), _scaling_tail(hamt)]
			return "%sHeals %s for %d HP" % [_sentence_case(cond), who, int(hamt)]
		"gain_energy":
			var col := str(b.get("colour", ""))
			return "%sGains %d %s energy" % [_sentence_case(cond), int(b.get("amount", 1)), "random" if col == "" else col.capitalize()]
		"cleanse":
			return _sentence_case(cond) + _describe_cleanse(b, who)
		"remove":
			return _sentence_case(cond) + _describe_remove(b, who)
		"adjust":
			return _sentence_case(cond) + _describe_adjust(b, who)
		"banish":
			# Author turns, printed as authored — the 2N conversion is the runner's business.
			var bt := int(b.get("turns", 1))
			var bdur := "permanently" if bt < 0 else ("for %d turn%s" % [bt, "" if bt == 1 else "s"])
			return "%sBanishes %s %s" % [_sentence_case(cond), who, bdur]
		"repeat":
			# The count goes FIRST, and that is the whole point of the sentence: a reader has to
			# know they are looking at N separate hits before they read the size of one.
			var reps: Array = []
			for sub in b.get("blocks", []):
				var s := _describe_block(sub)
				if s != "":
					reps.append(s)
			if reps.is_empty():
				return ""
			var tv = b.get("times", 1)
			if tv is Dictionary:
				return "%sOnce per %s: %s" % [_sentence_case(cond), _reading_noun(tv), "; ".join(reps)]
			return "%s%d times: %s" % [_sentence_case(cond), int(tv), "; ".join(reps)]
		"break":
			match str(b.get("what", "shield")):
				"barrier": return "%sDestroys %s destructible defense" % [_sentence_case(cond), _possessive(who)]
				"both":    return "%sDestroys %s shields and destructible defense" % [_sentence_case(cond), _possessive(who)]
				_:         return "%sDestroys %s shields" % [_sentence_case(cond), _possessive(who)]
		"apply":
			return _sentence_case(cond) + _describe_effect(b.get("effect", {}), who)
		"group":
			var subs: Array = []
			for sub in b.get("blocks", []):
				var s := _describe_block(sub)
				if s != "":
					subs.append(s)
			# A branching group prints BOTH arms with an "otherwise" — the `when` is already folded into
			# `cond` above, so the sentence reads "if C, <blocks>; otherwise <else>". Exactly one runs.
			if b.get("else", null) is Array:
				var elses: Array = []
				for sub in b.get("else", []):
					var es := _describe_block(sub)
					if es != "":
						elses.append(es)
				var thenp := "; ".join(subs) if not subs.is_empty() else "nothing happens"
				var elsep := "; ".join(elses) if not elses.is_empty() else "nothing happens"
				return "%s%s; otherwise %s" % [_sentence_case(cond), thenp, elsep]
			return (_sentence_case(cond) + "; ".join(subs)) if not subs.is_empty() else ""
		"execute":
			# The threshold is a hp_below, so the readable clause is "below N HP" (hp <= N-1).
			if b.has("hp_below"):
				return "%sInstantly kills %s below %d HP" % [_sentence_case(cond), who, int(b["hp_below"])]
			return "%sInstantly kills %s" % [_sentence_case(cond), who]
		"revive":
			return "%sRevives %s with %d HP" % [_sentence_case(cond), who, int(b.get("amount", 0))]
		"cooldown":
			var cd_amt := int(b.get("amount", 0))
			var cd_names := _describe_skill_list(b.get("skills", []))
			var verb := "Reduces" if cd_amt < 0 else "Increases"
			var turns_abs: int = absi(cd_amt)
			# "on the user" reads oddly for the self-default; only name the character when it is not self.
			var whose := "" if str(b.get("to", "user")) == "user" else (" on %s" % who)
			return "%s%s the cooldown of %s%s by %d turn%s" % [_sentence_case(cond), verb, cd_names, whose, turns_abs, "" if turns_abs == 1 else "s"]
		"drain_energy":
			var tail := ", stealing it" if bool(b.get("steal", false)) else ""
			return "%sDrains %d energy from %s%s" % [_sentence_case(cond), int(b.get("amount", 1)), _possessive(who) + " team", tail]
		"seal":
			var tail := " (this is not a Stun and cannot be ignored)" if _seal_seals_all(b) else ""
			return "%sSeals %s, stopping %s from using %s%s" % [_sentence_case(cond), who, who, _seal_which(b), tail]
	return ""

# WHICH skills the seal locks out, from the three filter lists. Empty everywhere is "every skill".
func _seal_which(b: Dictionary) -> String:
	var classes := _describe_skill_list(b.get("classes", []))
	var skills := _describe_name_list(b.get("skills", []))
	var parts: Array = []
	if b.get("classes", []) is Array and not (b.get("classes", []) as Array).is_empty():
		parts.append(classes + " skills")
	if b.get("skills", []) is Array and not (b.get("skills", []) as Array).is_empty():
		parts.append(skills)
	var body := "any skill"
	if not parts.is_empty():
		body = " or ".join(parts)
	var ex = b.get("exclude_skills", [])
	if ex is Array and not (ex as Array).is_empty():
		body += " (except " + _describe_name_list(ex) + ")"
	var st := int(b.get("turns", 1))
	var sdur := "permanently" if st < 0 else ("for %d turn%s" % [st, "" if st == 1 else "s"])
	return "%s %s" % [body, sdur]

func _seal_seals_all(b: Dictionary) -> bool:
	for k in ["classes", "skills", "exclude_skills"]:
		var v = b.get(k, [])
		if v is Array and not (v as Array).is_empty():
			return false
	return true

# A plain comma list of names (skills, classes), verbatim. Distinct from _describe_skill_list, whose
# empty case is the cooldown-op's "their skills".
func _describe_name_list(v) -> String:
	if not v is Array or (v as Array).is_empty():
		return ""
	var names: Array = []
	for n in v:
		names.append(str(n))
	return ", ".join(names)

# A skill list for `cooldown` prose. An empty list is "every skill"; otherwise the names verbatim.
func _describe_skill_list(v) -> String:
	if not v is Array or (v as Array).is_empty():
		return "their skills"
	var names: Array = []
	for n in v:
		names.append(str(n))
	return ", ".join(names)

# Author-facing turn count for an effect spec. A raw `ticks` is an ENGINE duration (every
# side's turn ticks it), so it is halved back before it reaches player-facing prose —
# printing the raw number would promise twice the duration the player actually gets.
# Rounded UP because an odd duration is the "…and this turn too" shape (broly2's counter 5).
func _duration_turns(spec) -> int:
	if not spec is Dictionary:
		return 1
	if spec.has("ticks"):
		var raw := int(spec["ticks"])
		return -1 if raw < 0 else int(ceil(float(raw) / 2.0))
	return int(spec.get("turns", 1))

func _describe_effect(spec, who: String) -> String:
	if not spec is Dictionary:
		return ""
	var turns := _duration_turns(spec)
	var dur_txt := "permanently" if turns < 0 else ("for %d turn%s" % [turns, "" if turns == 1 else "s"])
	var amount := int(spec.get("amount", 0))
	# canonical_kind: a character saved before the reactive->trigger rename still reads
	# "reactive" off disk, and its description must still be generated.
	match BlockSchema.canonical_kind(spec.get("kind", "")):
		"mark":
			var ceiling := int(spec.get("max", 1))
			if ceiling > 1:
				var initial := int(spec.get("stacks", 1))
				return "Marks %s with %d stack%s %s (stacks up to %d)" % [who, initial, "" if initial == 1 else "s", dur_txt, ceiling]
			return "Marks %s %s" % [who, dur_txt]
		"damage_over_time":
			var dt := str(spec.get("damage_type", "NORMAL"))
			var dtxt := "" if dt == "NORMAL" else " " + dt.capitalize()
			if bool(spec.get("delayed", false)):
				return "%s %s %d%s damage after %d turn%s" % [_sentence_case(who), _verb(who, "takes", "take"), amount, dtxt, turns, "" if turns == 1 else "s"]
			return "%s %s %d%s damage per turn %s" % [_sentence_case(who), _verb(who, "takes", "take"), amount, dtxt, dur_txt]
		"heal_over_time":    return "%s %s %d HP per turn %s" % [_sentence_case(who), _verb(who, "heals", "heal"), amount, dur_txt]
		"shield":            return "%s %s %d Shield %s" % [_sentence_case(who), _verb(who, "gains", "gain"), amount, dur_txt]
		"stun":
			var excl := _name_list(spec.get("exclude_classes", []))
			if excl != "":
				return "Stuns %s non-%s skills %s" % [_possessive(who), excl, dur_txt]
			var only := _name_list(spec.get("classes", []))
			if only != "":
				return "Stuns %s %s skills %s" % [_possessive(who), only, dur_txt]
			return "Stuns %s %s" % [who, dur_txt]
		"invulnerable":      return "%s %s invulnerable %s" % [_sentence_case(who), _verb(who, "becomes", "become"), dur_txt]
		"ignore_damage":     return "%s %s all damage %s" % [_sentence_case(who), _verb(who, "ignores", "ignore"), dur_txt]
		"damage_reduction":  return "%s %s %d damage reduction %s" % [_sentence_case(who), _verb(who, "gains", "gain"), amount, dur_txt]
		"vulnerability":
			# The type filter inserts "non-Affliction "/"Affliction " ahead of "damage", REUSING
			# _damage_type_phrase (its trailing space is built in, so the caller writes "%sdamage").
			# ABSENT filters -> "" -> byte-for-byte the shipped sentence ("takes 5 more damage ...").
			# nonon1 reads "takes 5 more non-Affliction damage". `amount` is unsigned here (a
			# vulnerability is always "more"), so there is no "less"/absi dance the signed damage_boost
			# needs.
			var vu_type := _damage_type_phrase(spec.get("include_types", []), spec.get("exclude_types", []))
			return "%s %s %d more %sdamage %s" % [_sentence_case(who), _verb(who, "takes", "take"), amount, vu_type, dur_txt]
		"damage_boost":
			var db_skills := _name_list(spec.get("skills", []))
			var db_inc = spec.get("include_types", [])
			var db_exc = spec.get("exclude_types", [])
			var db_filtered := (db_inc is Array and not (db_inc as Array).is_empty()) or (db_exc is Array and not (db_exc as Array).is_empty())
			# BYTE-FOR-BYTE the shipped sentence when there is no type filter AND the amount is a boost
			# (>= 0): signed/filter support is additive and must not change one existing damage_boost card.
			if amount >= 0 and not db_filtered:
				if db_skills != "":
					return "%s %s %d more damage with %s %s" % [_sentence_case(who), _verb(who, "deals", "deal"), amount, db_skills, dur_txt]
				return "%s %s %d more damage %s" % [_sentence_case(who), _verb(who, "deals", "deal"), amount, dur_txt]
			# A negative amount reads as a weaken ("less"), a positive as a boost ("more"); the type filter
			# inserts "non-Affliction "/"Affliction " so the ladydevimon3 shape reads "deals 10 less
			# non-Affliction damage". absi so "-10 less" never prints.
			var db_dir := "more" if amount >= 0 else "less"
			var db_type := _damage_type_phrase(db_inc, db_exc)
			var db_with := "" if db_skills == "" else " with " + db_skills
			return "%s %s %d %s %sdamage%s %s" % [_sentence_case(who), _verb(who, "deals", "deal"), absi(amount), db_dir, db_type, db_with, dur_txt]
		"silence":           return "Silences %s %s" % [who, dur_txt]
		"destructible_break":return "Breaks %s destructible defense %s" % [_possessive(who), dur_txt]
		"trigger":
			var when_txt := _describe_trigger_hook(str(spec.get("trigger", "")), spec.get("scope", null))
			return "%s %s: %s" % [_sentence_case(dur_txt), when_txt, _describe_payload(spec)]
		"recurring":
			# "each turn" MEANS THE AUTHOR'S TURN — the tick set is scoped by the effect's user's
			# side, so an enemy-planted ticker fires on the caster's turn — hence "on each of your
			# turns", never "each turn" bare (which a reader takes as the holder's). `first` is
			# reflected because it moves the first payload a whole turn: "starting this turn" for
			# `now`, "starting next turn" for `next`. stops_when_stunned is surfaced too — it is the
			# whole reason this is a field and not a silent class chip.
			var rc_when := "starting this turn" if str(spec.get("first", "next")) == "now" else "starting next turn"
			var rc_span := ""
			if turns < 0:
				rc_span = "On each of your turns (%s)" % rc_when
			else:
				rc_span = "On each of your turns for %d turn%s (%s)" % [turns, "" if turns == 1 else "s", rc_when]
			var rc_stun := " — but not on a turn you are stunned" if bool(spec.get("stops_when_stunned", false)) else ""
			return "%s%s: %s" % [rc_span, rc_stun, _describe_payload(spec)]
		"counter":
			# `scope` is a shortcut name or a raw class list (korra1 watches only Affliction). `exclude`
			# subtracts a class from it — "harmful skill (except Strategic)" — and prints as an " (except
			# X)" tail off "skill"; empty when nothing is excluded, so the no-exclude card is unchanged.
			var scope_txt := _scope_noun(spec.get("scope", "harmful"))
			var excl := _except_suffix(spec.get("exclude", []))
			var payload := _describe_payload(spec)
			# The two sides read as different sentences, not one sentence with a clause: an outgoing
			# counter muzzles the character it sits on, and "used on them" vs "they use" is the whole
			# difference between a gift and an attack.
			var head := ""
			if str(spec.get("on", "incoming")) == "outgoing":
				head = "%s the next %s%s %s %s is countered" % [_sentence_case(dur_txt), scope_txt, excl, who, _verb(who, "uses", "use")]
			else:
				head = "%s the next %s%s used on %s is countered" % [_sentence_case(dur_txt), scope_txt, excl, who]
			return head if payload == "" else head + ", then: " + payload
		"reflect":
			# Destination and charges BOTH print, because both change what a player should do about it:
			# a bounce punishes the attacker, a guardian pull decides who eats the skill, and "the next
			# one" versus "all of them" decides whether it is worth spending a skill to bait it out.
			# `exclude` prints the same " (except X)" tail as `counter`, after the (possibly pluralised)
			# noun — "harmful skills (except Strategic)" — and is empty on a reflect that omits it.
			var rf_scope := _scope_noun(spec.get("scope", "harmful"))
			var rf_excl := _except_suffix(spec.get("exclude", []))
			var rf_where := "onto the user" if str(spec.get("destination", "attacker")) == "applier" else "back at whoever used it"
			if int(spec.get("charges", -1)) == 1:
				return "%s the next %s%s used on %s is reflected %s" % [_sentence_case(dur_txt), rf_scope, rf_excl, who, rf_where]
			return "%s %ss%s used on %s are reflected %s" % [_sentence_case(dur_txt), rf_scope, rf_excl, who, rf_where]
		"redirect":
			# WHO absorbs and HOW MUCH both print: the fraction decides how much the redirect is worth
			# baiting, and the destination decides who a player must protect (or finish off to break it —
			# a dead absorber ends the redirect). `amount` is the percentage moved.
			return "%s %d%% of the damage %s takes is redirected to %s" % [_sentence_case(dur_txt), amount, who, _describe_destination(spec.get("destination", {}))]
		"swap":
			return "%s %s is replaced by %s" % [_sentence_case(dur_txt), _skill_name_at(int(spec.get("slot", -1)), "this skill"), _skill_name_at(int(spec.get("into", -1)), "another skill")]
		# Both modifiers are SIGNED, so the prose has to swing with the sign — "cost -1
		# more energy" is not English, and an author reading it back would think their
		# discount had been rejected. The wording tracks the engine's own tooltip for
		# these effects (Effect.cost_mod_effect writes " more"/" less"), so the generated
		# description and the effect the player inspects in battle agree.
		"cost_change":
			var col := str(spec.get("colour", "random")).capitalize()
			var which := _name_list(spec.get("skills", []))
			var subject := "%s skills" % _possessive(who) if which == "" else which
			# THREE SENTENCES for three mechanics. They are not degrees of one thing — "1 more Blue",
			# "exactly 1 Blue" and "Blue instead of Green" are three different pieces of information
			# and a player reading the wrong one plans the wrong turn.
			match str(spec.get("mode", "add")):
				"set":
					if amount <= 0:
						return "%s cost no energy at all %s" % [_sentence_case(subject), dur_txt]
					return "%s cost exactly %d %s energy %s, whatever they cost normally" % [_sentence_case(subject), amount, col, dur_txt]
				"swap":
					return "%s cost %s energy instead of %s %s" % [_sentence_case(subject), col, str(spec.get("from", "")).capitalize(), dur_txt]
			var cost_dir := "more" if amount >= 0 else "less"
			return "%s cost %d %s %s energy %s" % [_sentence_case(subject), absi(amount), cost_dir, col, dur_txt]
		"cooldown_change":
			var cd_which := _name_list(spec.get("skills", []))
			var cd_subject := "%s skills" % _possessive(who) if cd_which == "" else cd_which
			var cd_dir := "increased" if amount >= 0 else "reduced"
			return "%s have their cooldowns %s by %d %s" % [_sentence_case(cd_subject), cd_dir, absi(amount), dur_txt]
		"paralyze":           return "%s cooldowns are paralyzed %s" % [_sentence_case(_possessive(who)), dur_txt]
		# Honest and index-agnostic: the alt-portrait slot the transform points at is a cosmetic upload,
		# not a mechanic, so the prose names the transform and its duration, never the raw index.
		"portrait_change":    return "%s %s transforms" % [_sentence_case(dur_txt), who]
		"taunt":              return "Taunts %s %s" % [who, dur_txt]
		"effect_immunity":    return "%s %s %s effects %s" % [_sentence_case(who), _verb(who, "ignores", "ignore"), str(spec.get("effect", "")).capitalize(), dur_txt]
	# PHASE C — the Simple Effect Table's generated clause. ONE arm for every row: the sentence is the
	# row's `prose` template (BlockSchema.SIMPLE_EFFECTS), written from the READER's semantics, filled
	# with {who} / {poss} / {amount} / {dur}. This is the ability card's contract for these kinds; the
	# templates are transitive ("Isolates {who}", "Caps the damage {who} deals") so they need no
	# singular/plural verb agreement, the same shape stun/silence/taunt already use above.
	var scanon := BlockSchema.canonical_kind(spec.get("kind", ""))
	if BlockSchema.SIMPLE_EFFECTS.has(scanon):
		var tmpl := str(BlockSchema.SIMPLE_EFFECTS[scanon].get("prose", ""))
		if tmpl == "":
			return ""
		return _sentence_case(tmpl.format({"who": who, "poss": _possessive(who), "amount": amount, "dur": dur_txt}))
	return ""

# "harmful skill" / "Physical or Energy skill" / plain "skill" — the noun `counter` and `reflect`
# both hang their sentence on.
#
# ONE RENDERER. This and _scope_phrase are now two shapes of BlockSchema.scope_words (the noun form
# and the adjective form) rather than two independent openings of the same authored value. They
# disagreed on BOTH halves: this one ran a raw class list through _name_list and joined it with
# " and " — which says the opposite of what BlockRunner._scope_matches does, since it returns true
# on the FIRST class that matches — while _scope_phrase resolved the shortcut to its CLASS NAMES and
# joined with " or ". Same spec, two sentences on one card.
func _scope_noun(scope) -> String:
	var words := BlockSchema.scope_words(scope)
	return "skill" if words.is_empty() else words + " skill"

# The " (except X)" clause a counter/reflect card hangs off "skill" when an `exclude` subtracts a
# class from the scope. Empty when nothing is subtracted, so the no-exclude sentence is byte-for-byte
# what the card showed before this field existed — purely additive. Uses the SAME " or "-joined
# disjunction _scope_noun renders (via scope_words), because a skill is let through if it carries ANY
# excluded class. Kept OUT of _scope_noun so reflect can pluralise the bare noun ("skills") and then
# append the tail — folding it into the noun would produce "skill (except X)s".
func _except_suffix(exclude) -> String:
	var words := BlockSchema.scope_words(exclude)
	return "" if words.is_empty() else " (except %s)" % words

# The nested block list shared by `trigger` and `counter`.
func _describe_payload(spec) -> String:
	var inner: Array = []
	for sub in spec.get("then", []):
		var s := _describe_block(sub)
		if s != "":
			inner.append(s)
	return "; ".join(inner)

# A swap names two of the character's OWN skills by moveset index. The names only
# exist once the ability is attached to a character, so fall back to a generic
# phrase for the offline description pass that builds the client's ability JSON.
func _skill_name_at(idx: int, fallback: String) -> String:
	if idx < 0 or user == null or not is_instance_valid(user):
		return fallback
	var kit = user.moveset.base_abilities if user.moveset != null else []
	if idx >= kit.size():
		return fallback
	return str(kit[idx].ability_name)

# "Rip, Tear and Devour" from a list of skill/class names; "" when the list is empty.
func _name_list(v) -> String:
	if not v is Array or v.is_empty():
		return ""
	var names: Array = []
	for x in v:
		names.append(str(x))
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]

# A damage_boost's type filter -> a leading noun-modifier for "damage" (with a trailing space so the
# caller writes "%sdamage"). include -> "Affliction " / "Affliction or Physical "; exclude ->
# "non-Affliction " / "non-Affliction, non-Piercing ". "" when neither is set (unfiltered). Names are
# uppercase DAMAGE_TYPES members; capitalize() renders "AFFLICTION" as "Affliction".
func _damage_type_phrase(inc, exc) -> String:
	var out := ""
	if inc is Array and not (inc as Array).is_empty():
		var incl: Array = []
		for t in inc:
			incl.append(str(t).capitalize())
		out += " or ".join(incl) + " "
	if exc is Array and not (exc as Array).is_empty():
		var excl: Array = []
		for t in exc:
			excl.append("non-" + str(t).capitalize())
		out += ", ".join(excl) + " "
	return out

func _describe_cleanse(b: Dictionary, who: String) -> String:
	var nm := str(b.get("name", ""))
	var scope := str(b.get("scope", "hostile"))
	var count := int(b.get("count", 0))
	var what := "harmful effects"
	if scope == "own":
		what = "beneficial effects"
	elif scope == "any":
		what = "effects"
	if nm != "":
		what = "%s (%s)" % [what, nm]
	var how_many := "all" if count <= 0 else str(count)
	return "Removes %s %s from %s" % [how_many, what, who]

# `remove` has TWO sentences because it is two different player-facing acts. Taking an effect
# away reads as removal ("Removes Ganta Fever from the user"); spending stacks of a resource
# reads as spending ("Spends 1 stack of Ganta Fever from the user"), and an author who typed a
# count has to see that count come back or they cannot tell the two forms apart.
#
# The `effect` TYPE is deliberately absent from the prose. It is a disambiguator for the
# MATCH — which of two same-named effects to take — and "Removes Ganta Fever (MARK)" tells a
# player nothing they can act on. The name is what is written on the pip they can see.
func _describe_remove(b: Dictionary, who: String) -> String:
	var nm := str(b.get("name", "")).strip_edges()
	if nm.is_empty():
		nm = "an effect"
	var spec = b.get("stacks", BlockSchema.REMOVE_ALL)
	var count := int(spec) if (spec is int or spec is float) else 0
	if count > 0:
		return "Spends %d stack%s of %s from %s" % [count, "" if count == 1 else "s", nm, who]
	return "Removes %s from %s" % [nm, who]

# `adjust` prints ONE SENTENCE PER AXIS, joined the way a group joins its children, rather than one
# sentence with three clauses hung off it. Three axes give six possible verbs and there is no
# English phrasing that carries "one turn longer, two stacks fewer and five points weaker" in a
# single readable clause — and an author who typed three deltas has to see all three come back or
# they cannot tell which one the editor dropped.
#
# The `effect` TYPE is absent for exactly the reason it is absent from `remove`'s prose: it is a
# disambiguator for the MATCH, and "(MARK)" tells a player nothing they can act on. The delta is
# always printed as a magnitude with a direction word, never as a signed number, because "-1 turns"
# is not English.
func _describe_adjust(b: Dictionary, who: String) -> String:
	var nm := str(b.get("name", "")).strip_edges()
	if nm.is_empty():
		nm = "an effect"
	var lines: Array = []
	var dt := int(b.get("turns", 0))
	if dt != 0:
		var n := absi(dt)
		lines.append("%s %s on %s by %d turn%s" % ["Extends" if dt > 0 else "Shortens", nm, who, n, "" if n == 1 else "s"])
	var ds := int(b.get("stacks", 0))
	if ds != 0:
		var n2 := absi(ds)
		if ds > 0:
			lines.append("Adds %d stack%s to %s on %s" % [n2, "" if n2 == 1 else "s", nm, who])
		else:
			lines.append("Removes %d stack%s from %s on %s" % [n2, "" if n2 == 1 else "s", nm, who])
	var dm := int(b.get("mag", 0))
	if dm != 0:
		lines.append("%s %s on %s by %d" % ["Strengthens" if dm > 0 else "Weakens", nm, who, absi(dm)])
	return "; ".join(lines)

# Upper-case only the first letter. String.capitalize() title-cases every word,
# which turns "for 2 turns" into "For 2 Turns" in player-facing text.
func _sentence_case(s: String) -> String:
	return s if s.is_empty() else s.substr(0, 1).to_upper() + s.substr(1)

# The selector decides the verb: "all enemies take", not "all enemies takes".
func _is_plural(who: String) -> bool:
	return who in ["all enemies", "all allies", "their other allies"]

func _verb(who: String, singular: String, plural: String) -> String:
	return plural if _is_plural(who) else singular

func _possessive(who: String) -> String:
	return (who + "'") if _is_plural(who) else (who + "'s")

# The ADJECTIVE form of the same one renderer _scope_noun uses ("harmful ", "Physical or Energy "),
# ready to sit directly in front of the word "skill". "" when the trigger is unscoped, or scoped to
# "any" — which resolves to an empty class list and therefore filters nothing worth saying out loud.
func _scope_phrase(scope) -> String:
	var words := BlockSchema.scope_words(scope)
	return "" if words.is_empty() else words + " "

# A scoped trigger has to NAME the class it waits for, or the player reads "whenever they use a
# skill" off a card that only fires on Harmful ones. That is why the scoped forms are written out
# rather than bolted on as a trailing clause: three of the six hooks have no "skill" noun in their
# plain wording at all ("when they take damage"), so there is nothing to attach an adjective to.
#
# ...EXCEPT where the hook has already said it. `on_harmful_received` + `scope: "harmful"` is a
# legal spec that printed "when a Harmful harmful skill is used on them", and the fix is not a
# find-and-replace on the sentence: on that hook a scope naming Harmful genuinely filters NOTHING
# (the hook only fires for Harmful skills, and the class list is an OR), so the honest sentence is
# the unscoped one. See BlockSchema.TRIGGER_IMPLIED_CLASS. A scope naming any other class still
# prints, because that one does narrow: "when a Physical harmful skill is used on them".
func _describe_trigger_hook(t: String, scope = null) -> String:
	var cls := _scope_phrase(scope)
	if cls != "" and BlockSchema.TRIGGER_IMPLIED_CLASS.has(t):
		var implied := str(BlockSchema.TRIGGER_IMPLIED_CLASS[t])
		for c in BlockSchema.counter_classes(scope):
			if str(c) == implied:
				cls = ""
				break
	if cls != "":
		match t:
			"on_harmful_received": return "when a %sharmful skill is used on them" % cls
			"on_damage_received":  return "when a %sskill damages them" % cls
			"on_damage_dealt":     return "when they deal damage with a %sskill" % cls
			"on_skill_used":       return "whenever they use a %sskill" % cls
			"on_skill_received":   return "whenever a %sskill is used on them" % cls
			"on_stunned":          return "when a %sskill stuns them" % cls
			"on_healing_given":    return "when they heal with a %sskill" % cls
	match t:
		"on_harmful_received": return "when a harmful skill is used on them"
		"on_damage_received":  return "when they take damage"
		"on_damage_dealt":     return "when they deal damage"
		"on_turn_start":       return "at the start of each turn"
		"on_turn_end":         return "at the end of each turn"
		"on_death":            return "when they die"
		"on_skill_used":       return "whenever they use a skill"
		"on_hp_changed":       return "whenever their health changes"
		"on_stunned":          return "when they are stunned"
		"on_skill_received":   return "whenever a skill is used on them"
		"on_healing_given":    return "when they heal someone"
	return "when triggered"

func _describe_selector(s: String) -> String:
	match s:
		"user":          return "the user"
		"all_enemies":   return "all enemies"
		"all_allies":    return "all allies"
		"other_allies":  return "their other allies"
		"random_enemy":  return "a random enemy"
		"random_ally":   return "a random ally"
		# Payload addressing. One noun each, singular, so _verb/_possessive need no special case
		# ("the holder's shields", "the holder gains 10 Shield").
		"holder":        return "the holder"
		"affected":      return "the character it happened to"
		# Bare fallbacks. A filtered selector normally reaches prose through
		# _describe_filtered, which folds its condition into the phrase.
		"any_enemy":     return "each enemy"
		"any_ally":      return "each ally"
		"any_character": return "each character"
	return "the target"

# A redirect's DESTINATION selector, folded to one noun phrase for the card. It is a Phase F
# selector object (pool x where x pick); the card names the pool and how it narrows so a reader knows
# who eats the redirected damage. Kept compact and separate from _describe_selector (which speaks the
# STRING selectors) because the pool vocabulary is its own.
func _describe_destination(sel) -> String:
	if not sel is Dictionary:
		return "another character"
	var pool := str(sel.get("pool", "other_allies"))
	var noun: String = {
		"allies": "an ally", "other_allies": "another ally", "enemies": "an enemy",
		"everyone": "another character", "user": "itself", "target": "the target",
		"main_target": "the primary target", "other_targets": "another target", "dead_allies": "a fallen ally",
	}.get(pool, "another character")
	var bare := noun
	for a in ["another ", "an ", "a ", "the "]:
		if bare.begins_with(a):
			bare = bare.substr(a.length())
			break
	match str(sel.get("pick", "all")):
		"random":  return "a random %s" % bare
		"lowest":  return "the lowest-%s %s" % [str(sel.get("measure", "hp")), bare]
		"highest": return "the highest-%s %s" % [str(sel.get("measure", "hp")), bare]
	return noun

# "each enemy below 40 HP" — the subject of a condition-filtered block. Deliberately a
# SINGULAR phrase ("each ..."), so _verb/_possessive read correctly without a special case.
func _describe_filtered(sel: String, cond) -> String:
	var head := _describe_selector(sel)
	var clause := _describe_filter(cond)
	return head if clause == "" else head + " " + clause

# The generated eligibility clause for a Layer-1 target object. One line, DIM, reusing _describe_filter
# for each `only` predicate so the object's card and a filtered selector's card read the same way.
func _describe_target_eligibility() -> String:
	if target_mode == "self":
		return ""
	var noun := "targets"
	match target_mode:
		"enemy":    noun = "enemies"
		"ally":     noun = "allies"
		"everyone": noun = "characters on either side"
	var clauses: Array = []
	for cond in target_only:
		var cl := _describe_filter(cond)
		if cl != "":
			clauses.append(cl)
	var body := (" " + " and ".join(clauses)) if not clauses.is_empty() else ""
	var extra := ""
	if target_pick == "lowest":
		extra = " with the lowest %s" % _measure_noun(target_measure)
	elif target_pick == "highest":
		extra = " with the highest %s" % _measure_noun(target_measure)
	var dead := " (dead ones included)" if target_include_dead else ""
	if body == "" and extra == "" and dead == "":
		return ""
	return "Can only be used on %s%s%s%s" % [noun, body, extra, dead]

# The GAP-2 per-candidate bypass clause. It REUSES the same condition->English helpers the `only`
# predicates print through (_describe_filter's adjectival "carrying …" form, falling back to
# _describe_condition's sentence form for the conditions that have no adjectival phrase, e.g. compare),
# so the bypass condition reads exactly like an eligibility one. "" when bypass_when is absent (or on a
# self skill, where invulnerability is not a targeting question) — that is what keeps the card unchanged.
func _describe_target_bypass() -> String:
	if target_bypass_when == null or target_mode == "self":
		return ""
	var subj := "a target"
	match target_mode:
		"enemy":    subj = "an enemy"
		"ally":     subj = "an ally"
		"everyone": subj = "a character"
	var phrase := _describe_filter(target_bypass_when)
	if phrase == "":
		phrase = _describe_condition(target_bypass_when)
	if phrase == "":
		return ""
	return "Bypasses invulnerability against %s %s" % [subj, phrase]

func _measure_noun(m: String) -> String:
	match m:
		"hp_percent": return "HP percentage"
		"missing_hp": return "missing HP"
	return "HP"

func _describe_filter(c) -> String:
	if not c is Dictionary:
		return ""
	match str(c.get("cond", "")):
		"has_effect":      return "carrying %s" % _presence_noun(c)
		"not_has_effect":  return "not carrying %s" % _presence_noun(c)
		"hp_below":        return "below %d HP" % int(c.get("value", 0))
		"hp_above":        return "above %d HP" % int(c.get("value", 0))
		"stacks_at_least": return "with %d+ stacks of %s" % [int(c.get("value", 1)), _presence_noun(c)]
		"chance":          return "(%d%% chance each)" % int(c.get("percent", 100))
		"energy_at_least": return "(%s)" % _describe_condition(c).trim_prefix("if ")
		"cost_color_at_least": return "(%s)" % _describe_condition(c).trim_prefix("if ")
		"compare":         return "(%s)" % _describe_compare(c).trim_prefix("if ")
	return ""

func _describe_condition(c) -> String:
	if not c is Dictionary:
		return ""
	match str(c.get("cond", "")):
		"has_effect":      return "if %s is present" % _presence_noun(c)
		"not_has_effect":  return "if %s is absent" % _presence_noun(c)
		"hp_below":        return "if HP is below %d" % int(c.get("value", 0))
		"hp_above":        return "if HP is above %d" % int(c.get("value", 0))
		"stacks_at_least": return "with %d+ stacks of %s" % [int(c.get("value", 1)), _presence_noun(c)]
		"chance":          return "%d%% of the time" % int(c.get("percent", 100))
		"energy_at_least": return "if %s has at least %d energy" % [_possessive(_describe_selector(str(c.get("of", "all_enemies")))) + " team", int(c.get("value", 0))]
		"cost_color_at_least": return "if this skill costs at least %d %s energy" % [int(c.get("value", 1)), str(c.get("colour", "")).capitalize()]
		"compare":         return _describe_compare(c)
	return ""

# The effect a presence condition is asking about. `by: "mine"` PRINTS, because it changes the
# answer: an enemy's same-named mark satisfies the default reading and not this one, and a player
# who cannot see which is meant cannot predict the skill.
#
# The `effect` TYPE deliberately does NOT print, for exactly the reason it is absent from `remove`
# and `adjust`'s prose: it is a disambiguator for the MATCH, and "(MARK)" tells a player nothing
# they can act on. The name is what is written on the pip they can see.
func _presence_noun(c: Dictionary) -> String:
	var nm := str(c.get("name", ""))
	return ("the user's own " + nm) if str(c.get("by", "any")) == "mine" else nm

func _describe_compare(c: Dictionary) -> String:
	var subject := _describe_selector(str(c.get("of", "all_enemies")))
	# A reading OBJECT value already names its own subject (its `of`), so it prints as a self-contained
	# noun ("the number of Ofuda on all enemies") and compares against the `than` number only.
	if c.get("value", null) is Dictionary:
		var rn := _reading_noun(c["value"])
		var thn := str(int(c.get("than", 0)))
		match str(c.get("op", "")):
			"gt": return "if the number of %s is above %s" % [rn, thn]
			"lt": return "if the number of %s is below %s" % [rn, thn]
			"eq": return "if the number of %s equals %s" % [rn, thn]
		return ""
	var value := str(c.get("value", "hp"))
	var reading := "HP"
	if value == "hp_percent":
		reading = "HP percentage"
	elif value == "alive_count":
		reading = "living members"
	match str(c.get("op", "")):
		"all_equal":  return "if %s all have the same %s" % [subject, reading]
		"any_differ": return "if %s differ in %s" % [subject, reading]
	var other := ("that of %s" % _describe_selector(str(c["vs"]))) if c.has("vs") else str(int(c.get("than", 0)))
	match str(c.get("op", "")):
		"gt": return "if %s %s is above %s" % [_possessive(subject), reading, other]
		"lt": return "if %s %s is below %s" % [_possessive(subject), reading, other]
		"eq": return "if %s %s equals %s" % [_possessive(subject), reading, other]
	return ""

# --- scaling amount / reading prose -----------------------------------------
# The tail clause of a scaling amount: "plus 5 per <noun>, up to 45". ONE clause, appended after the
# base ("Deals 15 damage to all enemies, plus 5 per Ofuda on all enemies, up to 45"). The generated
# prose is the CONTRACT — describe() is irrelevant — so this has to name the same three numbers the
# runner resolves (base is printed by the caller, per and cap here) and the reading's own subject.
func _scaling_tail(v) -> String:
	if not v is Dictionary:
		return ""
	# div divides the WHOLE base+per*count (BlockRunner._amount), so its clause sits AFTER the per-term
	# and BEFORE "up to N": "plus P per <noun>, divided by D, up to C" reads as the whole sum halved and
	# then capped — exactly what the runner delivers. div == 1 is the identity and prints nothing, so
	# every card authored before div existed stays byte-for-byte unchanged.
	var tail := "plus %d per %s" % [int(v.get("per", 0)), _reading_noun(v.get("each", {}))]
	var div := int(v.get("div", 1))
	if div != 1:
		tail += ", divided by %d" % div
	return "%s, up to %d" % [tail, int(v.get("cap", 0))]

# The noun a reading counts, with its own subject folded in ("stack of Ofuda on all enemies"). Used
# by the scaling tail, the repeat-times clause and the compare-value clause — the three slots a
# reading mounts in — so all three read the same way.
func _reading_noun(node) -> String:
	if not node is Dictionary:
		return "unit"
	var of_who := _describe_selector(str(node.get("of", "all_enemies")))
	var nm := str(node.get("name", ""))
	match str(node.get("read", "")):
		"stacks":       return ("stack of %s on %s" % [nm, of_who]) if nm != "" else ("stack on %s" % of_who)
		"effect_count": return ("%s on %s" % [nm, of_who]) if nm != "" else ("effect on %s" % of_who)
		"alive_count":  return "living %s" % of_who
		# dead_count's `of` is validated to a team pool, so the enemy pool reads "dead enemy" and either
		# ally pool "dead ally" — the scaling tail then prints "plus 25 per dead ally" naturally.
		"dead_count":   return "dead enemy" if str(node.get("of", "all_enemies")) == "all_enemies" else "dead ally"
		"hp":           return "HP on %s" % of_who
		"missing_hp":   return "missing HP on %s" % of_who
		"energy":       return "energy %s has" % of_who
		"duration":     return ("turn of %s on %s" % [nm, of_who]) if nm != "" else ("turn on %s" % of_who)
		"event":        return "point the triggering event dealt"
	return "unit"

# --- generated bot hints ----------------------------------------------------
# The v3 bot policy scores candidates from features seeded by bot_damage_hint()
# and, on the legacy path, by custom_behavior(). Authored abilities derive both
# from their blocks so a player-made character is a real opponent, not a no-op.
# The v3 policy reads a 7-bit semantic mask off each candidate. Shipped abilities get theirs from the
# baked table in training/bot_tags.json (keyed by ability_name); an AUTHORED ability has no source file
# to bake from, so bot_policy.get_bot_tags() looks for this property first:
#     if "bot_tags" in ability and int(ability.bot_tags) != 0
# It existed nowhere until now, so every authored ability scored 0 on every semantic feature and the
# bots played player-made characters blind. Bit values and their meanings must track
# training/bake_bot_tags.py - note def_negate is AMPLIFY there, not CONTROL.
const TAG_CONTROL := 1
const TAG_INVULN := 2
const TAG_MITIGATE := 4
const TAG_HEAL := 8
const TAG_MARK := 16
const TAG_REACTIVE := 32
const TAG_AMPLIFY := 64

var _tags_cache: int = -1

var bot_tags: int:
	get:
		if _tags_cache < 0:
			_tags_cache = _derive_tags(blocks)
		return _tags_cache

func _derive_tags(list) -> int:
	var mask := 0
	if not list is Array:
		return 0
	for b in list:
		if not b is Dictionary:
			continue
		match str(b.get("op", "")):
			"heal":
				mask |= TAG_HEAL
			"break":
				# Shattering a defence is the same intent the baker tags on def_negate.
				mask |= TAG_AMPLIFY
			# `remove` and `cleanse` contribute NO bit, and that is the honest answer rather
			# than an oversight. training/bake_bot_tags.py fingerprints Effect.<factory> CALLS
			# only — it does not look at remove_effect, consume_stack or any cleanse entry
			# point — so the 59 hand-written scripts that strip an effect score 0 on every
			# semantic feature too. None of the seven bits describes "takes an effect away":
			# AMPLIFY is specifically damage amplification (damage_mod / vulnerability /
			# def_negate in the baker) and CONTROL is action denial, so forcing either one on
			# would teach the policy something false about the skill. A "strip" bit would have
			# to be added to bake_bot_tags.py, bot_policy.gd and the trained weights together.
			"banish":
				# GROUNDED IN THE BAKER, not guessed: training/bake_bot_tags.py fingerprints
				# Effect.banish_effect alongside stun/paralyze/silence/taunt/isolate/blind as
				# CONTROL, and a banished character cannot act at all — the strongest form of the
				# action denial that bit describes.
				mask |= TAG_CONTROL
			"seal":
				# A skill seal locks the target out of using skills — the same action-denial the
				# CONTROL bit describes (the baker tags stun/paralyze/silence/isolate the same way).
				mask |= TAG_CONTROL
			# `adjust` contributes NO bit, the same honest answer `remove` and `cleanse` give. The
			# baker fingerprints Effect.<factory> CALLS only, so the hand-written `dot.duration += 2`
			# and `tracker.mag += 1` idioms score 0 on every semantic feature too; none of the seven
			# bits describes "changes a number on an effect already on the board", and forcing one
			# would teach the policy something false about the skill.
			"group", "repeat":
				# A repeat's REPETITIONS are a magnitude, not a semantic: the bits say WHAT a skill
				# does, and doing it three times does not make it a different kind of thing.
				# bot_damage_hint is where the count is read (see _block_damage).
				mask |= _derive_tags(b.get("blocks", []))
				# A branching group's `else` arm is one of the two outcomes — tag both, so the policy
				# sees what the skill can do on either roll.
				if b.get("else", null) is Array:
					mask |= _derive_tags(b["else"])
			"apply":
				var spec = b.get("effect", {})
				if not spec is Dictionary:
					continue
				# canonical_kind, so a pre-rename "reactive" still scores the REACTIVE bit.
				match BlockSchema.canonical_kind(spec.get("kind", "")):
					"shield", "shield_effect", "damage_reduction", "damage_reduction_effect":
						mask |= TAG_MITIGATE
					"invulnerable", "invuln_effect", "ignore_damage", "ignore_damage_effect":
						mask |= TAG_INVULN
					"heal_over_time", "healing_effect":
						mask |= TAG_HEAL
					"mark":
						mask |= TAG_MARK
					# The block kinds, not the factory names: the earlier list spelled this
					# "def_negate" (the factory) and so never matched an authored tree, which
					# is why destructible_break scored 0. Vulnerability is AMPLIFY in the
					# baker too — it multiplies incoming damage rather than controlling.
					"damage_boost", "damage_mod_effect", "destructible_break", "vulnerability":
						mask |= TAG_AMPLIFY
					# Action denial. bake_bot_tags.py groups stun/silence/paralyze/taunt/isolate
					# under CONTROL; the block palette's names for those belong there too.
					"stun", "silence", "paralyze", "taunt":
						mask |= TAG_CONTROL
					"cost_change", "cooldown_change":
						# Signed, so the tag is signed too. A POSITIVE modifier taxes the
						# enemy's tempo and is honest CONTROL. A NEGATIVE one is a discount
						# on an ally, and NONE of the seven bits describe that — AMPLIFY is
						# specifically damage amplification (damage_mod/vulnerability/def_negate
						# in the baker) and would teach the policy this skill boosts damage.
						# So a discount contributes no bit. That is not an oversight: the
						# baker doesn't fingerprint cost_mod_effect/cooldown_mod at all, so a
						# hand-written discount scores 0 on every semantic feature too, and an
						# authored one matching that is the consistent answer. A new bit for
						# "tempo buff" would have to be added to bake_bot_tags.py, bot_policy.gd
						# and the trained weights together.
						if int(spec.get("amount", 1)) > 0:
							mask |= TAG_CONTROL
					"effect_immunity":
						# Refusing control is a defensive posture, not control.
						mask |= TAG_MITIGATE
					# PHASE C Simple Effect rows, tagged EXACTLY as training/bake_bot_tags.py fingerprints
					# their factories (:43-51), so an authored one scores the same semantic bit a
					# hand-written one would — nothing guessed:
					#   CONTROL  : isolate, blind_effect, false_stun  (action denial)
					#   INVULN   : immortality_effect                 (cannot be killed)
					#   MITIGATE : barrier_effect, percent_dr, damage_cap, damage_cap_receive
					# Every OTHER Simple row (ignore_healing, chain_nullify, delay, dodge, sharpshooter,
					# stealth, no_boost, ignore_*, healing_received_mod, damage_reverse, ...) is UNTAGGED
					# on purpose: the baker fingerprints none of their factories, so a hand-written kit
					# using them scores 0 on every bit too, and forcing a bit on would teach the policy
					# something false — the same honest-zero the file already gives `remove`/`cleanse`.
					"isolate", "blind", "false_stun":
						mask |= TAG_CONTROL
					"immortality":
						mask |= TAG_INVULN
					"barrier", "percent_dr", "damage_cap", "damage_cap_receive":
						mask |= TAG_MITIGATE
					"trigger":
						# The trigger itself, plus whatever its payload does. TAG_REACTIVE keeps
						# its name on purpose: it is the BOT's semantic bit and must track
						# training/bake_bot_tags.py, which knows nothing about the block palette.
						mask |= TAG_REACTIVE
						mask |= _derive_tags(spec.get("then", []))
					"recurring":
						# A recurring builds Effect.trigger_effect (as a TICKING_TRIGGER), the exact
						# factory training/bake_bot_tags.py fingerprints as REACTIVE — so a hand-written
						# ticking kit scores the same bit. Plus whatever its per-turn payload does.
						mask |= TAG_REACTIVE
						mask |= _derive_tags(spec.get("then", []))
					"reflect":
						# REACTIVE ONLY, and that is grounded rather than cautious:
						# training/bake_bot_tags.py fingerprints Effect.reflect_effect in the same
						# alternation as trigger_effect and counter_effect (:50) and gives it no
						# other bit. A reflect does not DENY the action the way a counter does — it
						# re-aims it and lets it resolve — so CONTROL would teach the policy
						# something false.
						mask |= TAG_REACTIVE
					"redirect":
						# REACTIVE ONLY, same grounding as reflect: training/bake_bot_tags.py
						# fingerprints Effect.redirect_effect in that SAME alternation (:50), so a
						# hand-written redirect (halibel3, minene3) scores exactly this bit. A redirect
						# re-routes damage rather than denying the action, so no CONTROL bit.
						mask |= TAG_REACTIVE
					"counter":
						# counter_effect is REACTIVE in the baker, and it also denies an action.
						mask |= TAG_REACTIVE | TAG_CONTROL
						mask |= _derive_tags(spec.get("then", []))
	return mask


func bot_damage_hint():
	var total := 0
	for b in blocks:
		total += _block_damage(b)
	return total

func _block_damage(b) -> int:
	if not b is Dictionary:
		return 0
	match str(b.get("op", "")):
		"damage":
			return _amount_hint(b.get("amount", 0))
		"apply":
			var spec = b.get("effect", {})
			if spec is Dictionary and str(spec.get("kind", "")) == "damage_over_time":
				var turns := _duration_turns(spec)
				return _amount_hint(spec.get("amount", 0)) * (1 if bool(spec.get("delayed", false)) else max(turns, 1))
			# A recurring's payout is per-tick damage TIMES the number of ticks — amount x turns, the
			# same shape damage_over_time uses. Without the multiply the v3 policy sees only one tick
			# and values a 5-turn 10-damage ticker at 10, never picking it over a flat 15. Permanent
			# (turns < 0) counts as ONE tick: a hostile permanent is clamped to the cap anyway, and a
			# permanent self-recurring is rarely a damage skill — undercounting is the honest floor.
			if spec is Dictionary and BlockSchema.canonical_kind(spec.get("kind", "")) == "recurring":
				var rturns := _duration_turns(spec)
				var instances: int = 1 if rturns < 0 else max(rturns, 1)
				var per_tick := 0
				for sub in spec.get("then", []):
					per_tick += _block_damage(sub)
				return per_tick * instances
			return 0
		"group":
			var sum := 0
			for sub in b.get("blocks", []):
				sum += _block_damage(sub)
			# A branching group runs exactly ONE arm, so the honest hint is the larger branch's damage
			# — the bot should value the skill at what a cast deals, not the sum of both branches.
			if b.get("else", null) is Array:
				var esum := 0
				for sub in b["else"]:
					esum += _block_damage(sub)
				return maxi(sum, esum)
			return sum
		"repeat":
			# The count MULTIPLIES the hint, and this is not optional: without it a 3x10 skill
			# scores 10 to the v3 policy and is never selected over a flat 20, so the bot would
			# simply never play an authored character's repeat skill.
			var rsum := 0
			for sub in b.get("blocks", []):
				rsum += _block_damage(sub)
			return rsum * maxi(_times_hint(b.get("times", 1)), 1)
	return 0

# A scaling amount ({base, per, cap, each}) scores at its CAP — the single largest non-palette cost
# of Phase E, and NOT optional. int({...}) is 0, so an object amount would score ZERO, the v3 policy
# would never select any scaling skill, and a character whose best skill is a scaling one could not
# be practised against at all. The cap is the reachable ceiling and the honest upper bound of what
# the skill does; a flat amount stays exactly as before. (THE classic revert-fails case — see the
# probe: assert this returns cap, hand-revert to `int(...)`, watch it go red.)
func _amount_hint(v) -> int:
	if v is Dictionary:
		return int((v as Dictionary).get("cap", BlockSchema.LIMITS["max_amount"]))
	return int(v)

# A scaling repeat `times` scores at its own ceiling for the same reason _amount_hint scores at cap:
# an object here is a board-scaled repetition count the policy must not see as 0 (or crash on
# int({...})). max_repeat_times is the reachable ceiling the runner already clamps it to.
func _times_hint(v) -> int:
	if v is Dictionary:
		return BlockSchema.LIMITS["max_repeat_times"]
	return int(v)

func custom_behavior(context):
	var variations = []
	var dmg: int = bot_damage_hint()
	# PHASE F — an object-shaped `target` used to fall through the match to the single-target branch,
	# so the bot never AoE'd or healed an authored eligibility skill correctly. ONE update (shared
	# with the scaling/reading work): read the SIDE off target_mode (which the object also fills) and
	# whether the object WIDENED to a faction (shape:"all"), and score it like the equivalent string
	# mode. self/ally/everyone already name their side; the object's `enemy` + shape:"all" is the one
	# combination the old match had no arm for.
	var aoe: bool = (_target_is_object and target_shape == "all") or target_mode in ["all_enemies", "all_allies", "everyone"]
	match target_mode:
		"self":
			variations += behavior_self_panic_button(context, 20)
		"ally", "all_allies":
			if _has_healing():
				variations += behavior_single_target_heal(context, 40)
			else:
				variations += behavior_single_target_helpful(context, 30)
		"all_enemies", "everyone":
			variations += behavior_hostile_aoe_damage(context, max(dmg, 10))
		"enemy":
			if aoe:
				variations += behavior_hostile_aoe_damage(context, max(dmg, 10))
			elif dmg > 0:
				variations += behavior_single_target_damage(context, dmg)
			else:
				variations += behavior_single_target_hostile(context, 25)
		_:
			if dmg > 0:
				variations += behavior_single_target_damage(context, dmg)
			else:
				variations += behavior_single_target_hostile(context, 25)
	return variations

func _has_healing() -> bool:
	for b in blocks:
		if b is Dictionary:
			if str(b.get("op", "")) == "heal":
				return true
			var spec = b.get("effect", {})
			if spec is Dictionary and str(spec.get("kind", "")) in ["heal_over_time", "shield"]:
				return true
	return false
