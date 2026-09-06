extends Node

# ============================================================================
# CREATOR PHASE E — VALUE READING (scaling amounts).
#
# `base + per * count`, capped, where `count` is a reading node {read, of, name,
# effect} off the live board. The same reading mounts as a compare value and a
# repeat `times`. This probe asserts, per load-bearing item, the thing the
# roadmap's Verify section names — and pairs every NEGATIVE (a thing that must be
# rejected / must not be counted) with a POSITIVE control (the thing that IS), so
# a broken assertion cannot pass by never firing.
#
#   godot --headless --path <repo> res://training/tests/creator_reading_probe.tscn
#
# HAND-REVERSALS (each turns exactly its block red; quoted in the task writeup):
#   * bot scorer:  scripted_ability._amount_hint -> `return int(v)` unconditionally
#                  => the scaling-damage hint drops from cap (45) to 0.
#   * write-b4-read: delete the block_max_stacks write in block_runner._op_apply
#                  => a non-mark stackable effect pins at 1 (reads 1, not 3/5).
#   * effect_count filter: drop `if e.system and not e.display_system: continue`
#                  in block_runner._matching_effects => a hidden effect leaks into
#                  the count (HiddenWard reads 1, not 0).
#   * cap clamp:   remove `mini(total, cap)` in block_runner._amount
#                  => the scaled hit deals 65, not the capped 45.
#   * product bound: delete the `_body_has_scaling_amount` guard in the validator
#                  repeat arm => the reading-times-over-reading-amount spec validates.
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

func _apply(caster, spec: Dictionary, to: String, targets: Array, m, harmful := true) -> void:
	var ab := _mk({"name": "Apply " + str(spec.get("kind", "")), "target": "enemy",
		"blocks": [{"op": "apply", "to": to, "effect": spec}]}, caster, harmful)
	_cast(caster, ab, targets, m)

# A runner bound to caster+battle, for calling _resolve_reading directly with a controlled board.
func _runner(caster, m) -> BlockRunner:
	var ab := _mk({"name": "Reader", "target": "enemy", "blocks": [{"op": "damage", "amount": 0}]}, caster)
	return BlockRunner.new(ab, m, caster)

# A valid ability spec wrapper, for validator (product-bound / mandatory-cap) checks.
func _ab_spec(blocks: Array) -> Dictionary:
	return {"name": "Probe", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Harmful", "Damaging"], "blocks": blocks, "requires": []}

func _has_err(errs: Array, needle: String) -> bool:
	for e in errs:
		if needle in str(e):
			return true
	return false

func _ready():
	print("=== CREATOR PHASE E — value reading ===")

	# self_check() stays green — a schema change (COMPARE_VALUES shrank, READINGS added) must not
	# break the constant-vs-constant invariants Phase B/C rely on.
	_check(BlockSchema.self_check().is_empty(), "self_check() is green after the readings change")

	# ==================================================================================
	# 1. The SEVEN read enum values each return the right number on a constructed board.
	# ==================================================================================
	var s = _fresh(); var m = s["m"]; var caster = s["allies"][0]; var foes = s["foes"]
	var r := _runner(caster, m)

	# alive_count — negative/positive in one: 3 alive, then kill one -> 2.
	_check(r._resolve_reading({"read": "alive_count", "of": "all_enemies"}) == 3,
		"alive_count reads 3 living enemies")
	foes[0].dead = true
	_check(r._resolve_reading({"read": "alive_count", "of": "all_enemies"}) == 2,
		"alive_count drops to 2 after one enemy dies")

	# hp / missing_hp on the user (single-member selection, so no summing ambiguity).
	caster.health.max_hp = 100
	caster.health.hp = 37
	_check(r._resolve_reading({"read": "hp", "of": "user"}) == 37, "hp reads the user's 37")
	_check(r._resolve_reading({"read": "missing_hp", "of": "user"}) == 63, "missing_hp reads 100-37 = 63")

	# energy — a TEAM pool, read once off the first member's team (not summed per head).
	caster.team.energy.reset_pool()
	caster.team.energy.change_energy(Energy.Type.GREEN, 2)
	caster.team.energy.change_energy(Energy.Type.RED, 1)
	_check(r._resolve_reading({"read": "energy", "of": "user"}) == 3, "energy reads the team pool total 3")

	# stacks — SUM of stack_count over the named mark. Apply Ofuda x4 to the user.
	_apply(caster, {"kind": "mark", "max": 99, "stacks": 4, "turns": 5, "name_override": "Ofuda"}, "user", [caster], m, false)
	_check(r._resolve_reading({"read": "stacks", "name": "Ofuda", "effect": "MARK", "of": "user"}) == 4,
		"stacks reads 4 Ofuda stacks")

	# duration — remaining engine ticks of a named effect. `ticks:5` pins it exactly.
	_apply(caster, {"kind": "mark", "ticks": 5, "name_override": "Timer"}, "user", [caster], m, false)
	_check(r._resolve_reading({"read": "duration", "name": "Timer", "of": "user"}) == 5,
		"duration reads the 5 remaining ticks")

	# effect_count — covered in depth by the visibility section below; here the plain count.
	_check(r._resolve_reading({"read": "effect_count", "name": "Ofuda", "of": "user"}) == 1,
		"effect_count reads 1 Ofuda effect")

	# ==================================================================================
	# 2. A scaled amount CLAMPS at `cap` (build enough stacks to exceed it).
	# ==================================================================================
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	# 10 Ofuda stacks -> 15 + 5*10 = 65, capped to 45.
	_apply(caster, {"kind": "mark", "max": 99, "stacks": 10, "turns": 5, "name_override": "Ofuda"}, "all_enemies", [foes[0]], m)
	var victim = foes[1]
	var hp0: int = int(victim.health.hp)
	var scaling := {"base": 15, "per": 5, "cap": 45,
		"each": {"read": "stacks", "name": "Ofuda", "effect": "MARK", "of": "all_enemies"}}
	# Round-trip: validate -> build -> resolve. The spec must validate clean first.
	var rt_errs := BlockValidator.validate_ability(_ab_spec([{"op": "damage", "amount": scaling, "to": "target"}]))
	_check(rt_errs.is_empty(), "scaling-amount ability validates clean (round-trip gate): %s" % str(rt_errs))
	var dmg_ab := _mk({"name": "Ofuda Blast", "target": "enemy",
		"blocks": [{"op": "damage", "amount": scaling, "to": "target"}]}, caster)
	_cast(caster, dmg_ab, [victim], m)
	var dealt: int = hp0 - int(victim.health.hp)
	_check(dealt == 45, "scaled damage clamps at cap 45 (raw 65) — dealt %d" % dealt)

	# ==================================================================================
	# 3. bot_damage_hint returns `cap`, not 0 — THE classic revert-fails case.
	# ==================================================================================
	var hint: int = dmg_ab.bot_damage_hint()
	_check(hint == 45, "bot_damage_hint scores the scaling skill at cap 45 (not 0) — got %d" % hint)
	# Positive control: a FLAT damage block still scores its literal amount, so the hint path is live.
	var flat_ab := _mk({"name": "Flat", "target": "enemy", "blocks": [{"op": "damage", "amount": 30, "to": "target"}]}, caster)
	_check(flat_ab.bot_damage_hint() == 30, "control: a flat 30 damage still hints 30")

	# ==================================================================================
	# 4. effect_count is BLIND to display_system effects (correctness, not just balance).
	# ==================================================================================
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	r = _runner(caster, m)
	# A both-players-hidden effect (system, NOT display_system) and a visible one.
	_apply(caster, {"kind": "mark", "turns": 5, "system": true, "name_override": "HiddenWard"}, "user", [caster], m, false)
	_apply(caster, {"kind": "mark", "turns": 5, "name_override": "VisibleWard"}, "user", [caster], m, false)
	_check(r._resolve_reading({"read": "effect_count", "name": "HiddenWard", "of": "user"}) == 0,
		"effect_count is BLIND to the hidden (system) effect — reads 0")
	_check(r._resolve_reading({"read": "effect_count", "name": "VisibleWard", "of": "user"}) == 1,
		"control: effect_count DOES count the visible effect — reads 1")
	# Assert against the drift source directly: the reading and the wire-cluster filter must AGREE
	# about what is visible, or the reading leaks state the client never received.
	var clusters = caster.effects.get_effect_clusters(caster.effects.get_all_effects())
	var wire_names := ""
	for key in clusters.keys():
		wire_names += str(key[0]) + " "
	_check(not ("HiddenWard" in wire_names), "the hidden effect is absent from the wire clusters too (they agree)")
	_check("VisibleWard" in wire_names, "the visible effect IS in the wire clusters (they agree)")

	# ==================================================================================
	# 5. A NON-MARK stackable effect's stacks are readable and adjustable (write-before-read).
	# ==================================================================================
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	r = _runner(caster, m)
	# A stacking DoT (per_stack Bleed) applied with 3 stacks. Without the block_max_stacks write in
	# _op_apply, _stack_ceiling answers the default 1 and the generalized clamp pins it at 1.
	_apply(caster, {"kind": "damage_over_time", "amount": 5, "turns": 3, "stackable": true,
		"stacks": 3, "name_override": "Bleed"}, "target", [foes[0]], m)
	var st_read: int = r._resolve_reading({"read": "stacks", "name": "Bleed", "effect": "DAMAGE", "of": "all_enemies"})
	_check(st_read == 3, "a non-mark stackable effect READS 3 stacks (write-before-read) — got %d" % st_read)
	# Adjustable: +2 stacks -> 5.
	var adj_ab := _mk({"name": "Feed", "target": "enemy",
		"blocks": [{"op": "adjust", "name": "Bleed", "effect": "DAMAGE", "stacks": 2, "to": "target"}]}, caster)
	_cast(caster, adj_ab, [foes[0]], m)
	var st_read2: int = r._resolve_reading({"read": "stacks", "name": "Bleed", "effect": "DAMAGE", "of": "all_enemies"})
	_check(st_read2 == 5, "the same effect is ADJUSTABLE to 5 stacks — got %d" % st_read2)

	# ==================================================================================
	# 6. The PRODUCT BOUND rejects the repeat x reading quadratic; a legal reading is accepted.
	# ==================================================================================
	var reading := {"read": "stacks", "name": "Ofuda", "effect": "MARK", "of": "all_enemies"}
	var scale := {"base": 15, "per": 5, "cap": 45, "each": reading}

	# LEGAL: a single scaling damage.
	var e1 := BlockValidator.validate_ability(_ab_spec([{"op": "damage", "amount": scale, "to": "target"}]))
	_check(e1.is_empty(), "legal: single scaling damage accepted — %s" % str(e1))
	# LEGAL: a CONSTANT repeat count over a scaling amount (bounded by 12*cap*targets).
	var e2 := BlockValidator.validate_ability(_ab_spec([{"op": "repeat", "times": 3,
		"blocks": [{"op": "damage", "amount": scale, "to": "target"}]}]))
	_check(e2.is_empty(), "legal: constant-times repeat over a scaling amount accepted — %s" % str(e2))
	# LEGAL: a scaling repeat count over a CONSTANT amount (the pre-existing bound covers it).
	var e3 := BlockValidator.validate_ability(_ab_spec([{"op": "repeat", "times": reading,
		"blocks": [{"op": "damage", "amount": 10, "to": "target"}]}]))
	_check(e3.is_empty(), "legal: scaling-times repeat over a constant amount accepted — %s" % str(e3))
	# ILLEGAL: scaling times OVER scaling amount — the quadratic.
	var e4 := BlockValidator.validate_ability(_ab_spec([{"op": "repeat", "times": reading,
		"blocks": [{"op": "damage", "amount": scale, "to": "target"}]}]))
	_check(_has_err(e4, "quadratic"), "ILLEGAL: scaling-times over scaling-amount rejected as a quadratic")
	# ILLEGAL: a scaling-times repeat over a LARGE constant body — the 40-block WORK ceiling, not the
	# quadratic guard. A reading `times` counts at its worst case (max_repeat_times=12), so 12 x a
	# 6-block body = 72 > 40. Before the count-site fix this THREW `int({...})`, degraded to times=1,
	# and sailed through — the runaway the ceiling exists to stop. (This assertion was the coverage
	# gap that let the defect ship.)
	var big_body: Array = []
	for _i in range(6):
		big_body.append({"op": "damage", "amount": 10, "to": "target"})
	var e4b := BlockValidator.validate_ability(_ab_spec([{"op": "repeat", "times": reading, "blocks": big_body}]))
	_check(_has_err(e4b, "too many blocks"), "ILLEGAL: scaling-times over a large body hits the 40-block work ceiling — %s" % str(e4b))
	# ILLEGAL: NESTED scaling-times repeats — 12 x 12 x a small body blows the ceiling even though the
	# static block count looks tiny. Each level multiplies by max_repeat_times.
	var e4c := BlockValidator.validate_ability(_ab_spec([{"op": "repeat", "times": reading,
		"blocks": [{"op": "repeat", "times": reading, "blocks": [{"op": "damage", "amount": 10, "to": "target"}]}]}]))
	_check(not e4c.is_empty(), "ILLEGAL: nested scaling-times repeats are rejected (12x12 > 40) — %s" % str(e4c))

	# ==================================================================================
	# 7. MANDATORY cap on the per-term (validator rejects a scaling amount with no cap).
	# ==================================================================================
	var no_cap := {"base": 15, "per": 5, "each": reading}
	var e5 := BlockValidator.validate_ability(_ab_spec([{"op": "damage", "amount": no_cap, "to": "target"}]))
	_check(_has_err(e5, "cap"), "ILLEGAL: a scaling amount with no cap is rejected")
	# Positive control: the SAME amount WITH a cap validates, so the rejection is the cap, not the shape.
	var e6 := BlockValidator.validate_ability(_ab_spec([{"op": "damage",
		"amount": {"base": 15, "per": 5, "cap": 45, "each": reading}, "to": "target"}]))
	_check(e6.is_empty(), "control: the same amount WITH a cap validates — %s" % str(e6))

	# ==================================================================================
	# 8. The reading mounts as a COMPARE value (relational condition reads the board).
	# ==================================================================================
	var e7 := BlockValidator.validate_ability(_ab_spec([{"op": "damage", "amount": 10, "to": "target",
		"when": {"cond": "compare", "value": reading, "op": "gt", "than": 2}}]))
	_check(e7.is_empty(), "legal: a reading as a compare value validates — %s" % str(e7))
	# A reading value is a single number: a `vs` selector on it is rejected.
	var e8 := BlockValidator.validate_ability(_ab_spec([{"op": "damage", "amount": 10, "to": "target",
		"when": {"cond": "compare", "value": reading, "op": "gt", "vs": "user"}}]))
	_check(_has_err(e8, "single number"), "ILLEGAL: a reading compare value with a 'vs' selector is rejected")
	# Back-compat: the alive_count STRING still validates as a compare value (it MOVED to readings).
	var e9 := BlockValidator.validate_ability(_ab_spec([{"op": "damage", "amount": 10, "to": "target",
		"when": {"cond": "compare", "value": "alive_count", "op": "gt", "than": 1}}]))
	_check(e9.is_empty(), "back-compat: value:'alive_count' still validates — %s" % str(e9))

	# Runtime: a compare reading actually gates a block. Ofuda x3 on the board, "> 2" fires.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_apply(caster, {"kind": "mark", "max": 99, "stacks": 3, "turns": 5, "name_override": "Ofuda"}, "all_enemies", [foes[0]], m)
	var chp0: int = int(foes[1].health.hp)
	var gated := _mk({"name": "Gated", "target": "enemy", "blocks": [{"op": "damage", "amount": 20, "to": "target",
		"when": {"cond": "compare", "value": {"read": "stacks", "name": "Ofuda", "effect": "MARK", "of": "all_enemies"}, "op": "gt", "than": 2}}]}, caster)
	_cast(caster, gated, [foes[1]], m)
	_check(chp0 - int(foes[1].health.hp) == 20, "compare reading > 2 lets the block fire (3 Ofuda on board)")

	print("=== DONE: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
