extends Node

# ============================================================================
# Creator GAP-2 — bypass_when, the PER-CANDIDATE invulnerability bypass.
#
#   godot --headless --path <repo> res://training/tests/creator_bypass_when_probe.tscn
#
# The Layer-1 target object already carries `bypass_invuln`, an ALL-OR-NOTHING bypass (bypass every
# candidate or none). nonon3 "Concentrated Climax" needs something the all-or-nothing switch cannot
# express: it may TARGET an invulnerable enemy ONLY IF that enemy is marked, while an UNMARKED
# invulnerable enemy stays untargetable. `bypass_when` closes that: a CONDITION on the target object,
# evaluated once per candidate, ORed onto the bypass for THAT candidate alone.
#
# WHAT THIS PROVES, and how each assertion can fail:
#   1. VALIDATION — a well-formed bypass_when passes; an unknown-condition one and a `chance` one are
#      REJECTED (the same eligibility guards `only` earns, for the same target()-re-run reason). Pairs
#      every negative with the positive it is distinguished from.
#   2. REACH — a skill with bypass_when {has_effect MARKX} TARGETS a marked-invuln enemy (the reach the
#      flat bypass also has) but REFUSES an unmarked-invuln one (the reach it does NOT). Positive
#      control: a plain non-invuln enemy is always targetable.
#   3. HAND-REVERSE — drop the bypass_when wiring on the SAME ability instance (bypass falls back to the
#      single precomputed value) and the marked-invuln enemy becomes untargetable: the assertion FLIPS,
#      proving the per-candidate eval is load-bearing, not decorative.
#   4. NO-OP — an object target with NO bypass_when flags the byte-identical set a plain single-target
#      string skill does. `bypass_when` absent must be exactly today's behaviour.
#   5. PROSE — the generated card surfaces the bypass clause and names the condition.
# ============================================================================

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy: bool = (u == "BotEnemy")
	for cn in names: p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _fresh() -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _mk(spec: Dictionary, owner, harmful := true) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Authored Probe"))
	a.classes = {"Physical": harmful, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": not harmful, "Harmful": harmful, "Helpful": not harmful, "Instant": true,
		"Action": false, "Control": false, "Channeled": false, "Uncounterable": false,
		"Bypassing": false, "Stealthed": false, "Passive": false, "Preserves Channel": false,
		"Damaging": harmful}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

# Apply a named MARK from `caster` onto `who` (name via name_override, exactly as the selector probe).
func _mark(caster, who, nm: String, m) -> void:
	var ab := _mk({"name": "Mark " + nm, "target": "enemy", "blocks": [{"op": "apply", "to": "target",
		"effect": {"kind": "mark", "turns": 9, "text": "", "name_override": nm}}]}, caster, false)
	_cast(caster, ab, [who], m)

# Make `ch` invulnerable — the same invuln_effect(2) the nonon spec probe plants.
func _make_invuln(m, ch) -> void:
	var ctx = QueryContext.from_game_state(ch, m)
	var iv = Effect.invuln_effect(2)
	iv.set_source(ch.moveset.base_abilities[0])
	Character.add_allied_effect(ctx, ch, ch, iv, true)

# Run target() on a fresh flag state and collect the flagged characters (the .targeted snapshot idiom).
func _flagged(ability, user, battle) -> Array:
	var chars = battle.all_characters()
	for c in chars:
		c.targeted = false
	ability.user = user
	ability.target(user, battle)
	var out: Array = []
	for c in chars:
		if c.targeted:
			out.append(c)
	return out

func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not x in b:
			return false
	return true

func _mentions(errs: Array, needle: String) -> bool:
	for e in errs:
		if str(e).find(needle) != -1:
			return true
	return false

# A minimal, otherwise-clean ability spec carrying `t` as its target — for the validation pass.
func _spec_pw(t) -> Dictionary:
	return {"name": "PW", "target": t, "cooldown": 0, "cost": {}, "classes": ["Harmful"],
		"blocks": [{"op": "damage", "to": "target", "amount": 5}], "requires": []}

const OK_WHEN := {"cond": "has_effect", "name": "MARKX", "effect": "MARK", "by": "mine"}

func _ready():
	print("=== creator bypass_when probe: per-candidate invuln bypass (GAP-2) ===")

	# =====================================================================================
	# 1. VALIDATION — positive paired with two negatives, through the REAL BlockValidator.
	# =====================================================================================
	var ok_errs := BlockValidator.validate_ability(_spec_pw({"mode": "enemy", "bypass_when": OK_WHEN}))
	_check(ok_errs.is_empty(), "a well-formed bypass_when validates with 0 errors: %s" % str(ok_errs))
	var bad_cond := BlockValidator.validate_ability(_spec_pw({"mode": "enemy",
		"bypass_when": {"cond": "bogus_cond"}}))
	_check(_mentions(bad_cond, "bypass_when"),
		"an unknown-condition bypass_when is REJECTED, the path named: %s" % str(bad_cond))
	var bad_chance := BlockValidator.validate_ability(_spec_pw({"mode": "enemy",
		"bypass_when": {"cond": "chance", "percent": 50}}))
	_check(_mentions(bad_chance, "chance"),
		"a `chance` bypass_when is REJECTED — target() re-runs several times a turn (the eligibility guard)")
	# A non-object bypass_when is a hand-edited malformed control; it must not slip through as "any".
	var bad_type := BlockValidator.validate_ability(_spec_pw({"mode": "enemy", "bypass_when": "nope"}))
	_check(not bad_type.is_empty(), "a non-object bypass_when is REJECTED: %s" % str(bad_type))

	# =====================================================================================
	# 2. REACH — marked-invuln reachable, unmarked-invuln refused, clean always reachable.
	# =====================================================================================
	var g := _fresh(); var mm = g["m"]; var caster = g["allies"][0]
	var marked = g["foes"][0]     # MARKX + invulnerable — the combo the shipped target() reaches
	var bare = g["foes"][1]       # invulnerable, NO mark — the shipped target() refuses it
	var clean = g["foes"][2]      # neither — the positive control (an enemy skill always reaches it)
	_mark(caster, marked, "MARKX", mm)          # mark BEFORE invuln (a mark is not invuln-gated, but keep it clean)
	_make_invuln(mm, marked)
	_make_invuln(mm, bare)
	_check(marked.is_invuln() and marked.has_effect("MARKX", EffectType.Type.MARK, caster) != null,
		"(setup) marked foe is MARKX-marked AND invulnerable")
	_check(bare.is_invuln() and bare.has_effect("MARKX", EffectType.Type.MARK, caster) == null,
		"(setup) bare foe is invulnerable and NOT marked")

	var pw_obj := _mk({"name": "Bypass Test", "target": {"mode": "enemy", "bypass_when": OK_WHEN},
		"blocks": [{"op": "damage", "to": "target", "amount": 5}]}, caster)
	var flagged := _flagged(pw_obj, caster, mm)
	_check(marked in flagged,
		"REACH: bypass_when TARGETS the marked-invuln enemy (per-candidate bypass fired)")
	_check(not (bare in flagged),
		"REFUSE: bypass_when does NOT target the unmarked-invuln enemy (the condition is false for it)")
	_check(clean in flagged,
		"CONTROL: the plain non-invuln enemy is always targetable")

	# =====================================================================================
	# 3. HAND-REVERSE — drop the bypass_when wiring on the same instance; the reach vanishes.
	# =====================================================================================
	pw_obj.target_bypass_when = null   # bypass falls back to the single precomputed value (false here)
	var rev := _flagged(pw_obj, caster, mm)
	_check(not (marked in rev),
		"HAND-REVERSE: with bypass_when dropped, the marked-invuln enemy is UNtargetable (assertion flips)")
	_check(clean in rev, "HAND-REVERSE: the clean enemy is still targetable (only the bypass changed)")

	# =====================================================================================
	# 4. NO-OP — an object target with no bypass_when flags exactly what a plain string skill does.
	# =====================================================================================
	var g2 := _fresh(); var m2 = g2["m"]; var caster2 = g2["allies"][0]
	_make_invuln(m2, g2["foes"][0])    # one invuln enemy so "both refuse it" is a real test, not vacuous
	var plain_obj := _mk({"name": "Plain Obj", "target": {"mode": "enemy"},
		"blocks": [{"op": "damage", "to": "target", "amount": 5}]}, caster2)
	var plain_str := _mk({"name": "Plain Str", "target": "enemy",
		"blocks": [{"op": "damage", "to": "target", "amount": 5}]}, caster2)
	var fo := _flagged(plain_obj, caster2, m2)
	var fs := _flagged(plain_str, caster2, m2)
	_check(_same_set(fo, fs),
		"NO-OP: a bypass_when-less object target flags the identical set as a plain string 'enemy' skill")
	_check(not (g2["foes"][0] in fo) and g2["foes"][1] in fo and g2["foes"][2] in fo,
		"NO-OP: the invuln enemy is refused, the two clean enemies flagged (byte-identical to today)")

	# =====================================================================================
	# 5. PROSE — the generated card surfaces the bypass clause and names the condition.
	# =====================================================================================
	print("    prose -> " + str(pw_obj.split_desc() if pw_obj.target_bypass_when != null else "(reverted)"))
	# Re-read from a FRESH instance so the hand-reverse above does not blank the clause.
	var prose_obj := _mk({"name": "Bypass Test 2", "target": {"mode": "enemy", "bypass_when": OK_WHEN},
		"blocks": [{"op": "damage", "to": "target", "amount": 5}]}, caster)
	var line := ""
	for seg in prose_obj.split_desc():
		line += (str(seg[0]) if seg is Array else str(seg)) + " | "
	print("    " + line)
	_check("Bypasses invulnerability" in line, "prose surfaces the bypass_when clause")
	_check("MARKX" in line, "prose names the bypass condition's effect (MARKX)")

	print("=== DONE: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
