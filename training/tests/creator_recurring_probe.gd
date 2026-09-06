extends Node

# ============================================================================
# CREATOR PHASE D — the `recurring` effect kind.
#
# `recurring` builds a TICKING_TRIGGER whose payload is a nested `then` block list, run once every
# AUTHOR'S turn (sibling of trigger/counter). This probe asserts the five things the roadmap says
# the kind must guarantee, each paired with a positive control so a negative can actually FAIL:
#   * both `first` modes fire on the CORRECT turns (the 2K-1 vs 2K distinction — the cleanest
#     revert-fails case);
#   * an enemy-planted ticker fires on the CASTER's turn (the engine's side-scoping, honoured);
#   * the Action-classed ticker stops while its AUTHOR is stunned, and fires when not;
#   * an enemy-facing recurring of ANY duration (permanent included) VALIDATES and LANDS at the
#     authored duration — the invented hostile-placement cap was removed (owner ruling);
#   * the two-site last_turn_only fix: the COLLECTOR does not list a last_turn_only ticking-trigger
#     whose duration != 1, and the EXECUTOR does not run one — no phantom reorder tile;
#   * two recurring effects with different stops_when_stunned on one skill are rejected.
# Plus prose, bot hint, and the schema self-check.
#
#   godot --headless --path <repo> res://training/tests/creator_recurring_probe.tscn
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

# A minimal harmful/helpful ScriptedAbility with its class row set by hand — the same shape the
# Phase C probe uses, so the allied/hostile application path is exercised the way a real card would
# be. `action` sets the Action class directly (the stops_when_stunned wiring is tested separately).
func _mk(spec: Dictionary, owner, harmful := true, action := false) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Authored Probe"))
	a.classes = {"Physical": harmful, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": not harmful, "Harmful": harmful, "Helpful": not harmful, "Instant": true,
		"Action": action, "Control": false, "Channeled": false, "Uncounterable": false,
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

func _pass_turn(m):
	m.end_of_turn_effect_handling()

# The tick pass for one side, exactly as the real turn runs it: battle_manager collects the side's
# ticking effects (get_ticking_effect_information) and start_round_loop runs them through
# execute_ticking_effect. Drive that path explicitly for the ACTING side.
func _run_ticks(m, for_enemy: bool):
	var info = m.get_ticking_effect_information(for_enemy)
	for key in info.keys():
		for eff in info[key]:
			m.execute_ticking_effect(eff)

func _ticker_on(char):
	var t = char.get_effects_by_type(EffectType.Type.TICKING_TRIGGER)
	return t[0] if t.size() > 0 else null

func _spec(blocks: Array, tmode := "enemy") -> Dictionary:
	return {"name": "Probe", "target": tmode, "cooldown": 0, "cost": {},
		"classes": ["Harmful"], "blocks": blocks, "requires": []}

func _valid(blocks: Array, tmode := "enemy") -> bool:
	return BlockValidator.validate_ability(_spec(blocks, tmode)).is_empty()

func _prose_has(effect_spec: Dictionary, to: String, needle: String) -> bool:
	var a := ScriptedAbility.new()
	a.configure(_spec([{"op": "apply", "to": to, "effect": effect_spec}], "self"))
	for seg in a.split_desc():
		if str(seg).find(needle) != -1:
			return true
	return false

func _tags_of(blocks: Array) -> int:
	var a := ScriptedAbility.new()
	a.configure(_spec(blocks))
	return int(a.bot_tags)

func _hint_of(blocks: Array) -> int:
	var a := ScriptedAbility.new()
	a.configure(_spec(blocks))
	return int(a.bot_damage_hint())

func _ready():
	# Seeded even though every payload here is single-target-deterministic: the live-match probe
	# pattern uses a bare randi() the match seed does not reach, and a stray one would make an
	# assertion a coin flip. Belt and braces.
	seed(20260804)
	print("=== CREATOR PHASE D — the `recurring` kind ===")

	# ==================================================================================
	# 1. BOTH `first` MODES FIRE ON THE CORRECT TURNS — the 2K-1 vs 2K distinction.
	# ==================================================================================
	# Self-targeted (payload damages the holder = the caster), so no hostile cap and no RNG target
	# pick. K=3. `now` fires the payload once at cast (manual first instance) AND plants 2K-1=5; `next`
	# plants 2K=6 and the first lands on the author's NEXT turn. Both total 3 instances (30 damage);
	# the cast-turn value is where they differ, and it is the direct revert-fails signal.
	var s = _fresh(); var m = s["m"]; var caster = s["allies"][0]
	var payload := [{"op": "damage", "amount": 10, "to": "holder", "damage_type": "AFFLICTION"}]

	var ab_now := _mk(_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "recurring", "turns": 3, "first": "now", "then": payload}}], "self"), caster, false)
	var hp0: int = int(caster.health.hp)
	_cast(caster, ab_now, [caster], m)
	var cast_dmg_now: int = hp0 - int(caster.health.hp)
	_check(cast_dmg_now == 10, "first=now: the payload lands ONCE on the CAST turn (dealt %d, want 10)" % cast_dmg_now)
	var tick_total_now := 0
	for _i in range(6):
		var before := int(caster.health.hp)
		_pass_turn(m); _pass_turn(m)      # opponent, then back to the caster
		_run_ticks(m, false)              # the caster is on the player side
		tick_total_now += before - int(caster.health.hp)
	_check(cast_dmg_now + tick_total_now == 30, "first=now: 3 instances total over the window (%d)" % (cast_dmg_now + tick_total_now))

	s = _fresh(); m = s["m"]; caster = s["allies"][0]
	var ab_next := _mk(_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "recurring", "turns": 3, "first": "next", "then": payload}}], "self"), caster, false)
	hp0 = int(caster.health.hp)
	_cast(caster, ab_next, [caster], m)
	var cast_dmg_next: int = hp0 - int(caster.health.hp)
	_check(cast_dmg_next == 0, "first=next: NOTHING lands on the cast turn (dealt %d, want 0)" % cast_dmg_next)
	var tick_total_next := 0
	for _i in range(6):
		var before := int(caster.health.hp)
		_pass_turn(m); _pass_turn(m)
		_run_ticks(m, false)
		tick_total_next += before - int(caster.health.hp)
	_check(cast_dmg_next + tick_total_next == 30, "first=next: 3 instances total, all from ticks (%d)" % (cast_dmg_next + tick_total_next))

	# ==================================================================================
	# 2. SIDE-SCOPING — an ENEMY-planted ticker fires on the CASTER's (enemy) turn, not the holder's.
	# ==================================================================================
	# The caster is a FOE; it plants the ticker on a player character. The tick set is scoped by the
	# effect's USER's side, so it must fire when the ENEMY side ticks and stay silent when the PLAYER
	# side does — the roadmap's "an enemy-planted ticker fires on your turn", proven both directions.
	s = _fresh(); m = s["m"]
	var foe_caster = s["foes"][0]; var victim = s["allies"][0]
	var ab_side := _mk(_spec([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "turns": 2, "first": "now", "then": payload}}], "enemy"), foe_caster, true)
	var vh0: int = int(victim.health.hp)
	_cast(foe_caster, ab_side, [victim], m)
	_check(vh0 - int(victim.health.hp) == 10, "side-scoping: the manual first instance lands on the caster's (enemy) cast turn")
	# The PLAYER side ticks: the foe's ticker must NOT fire.
	var vh1: int = int(victim.health.hp)
	_pass_turn(m)                          # to the player side
	_run_ticks(m, false)                   # player-side tick pass
	_check(int(victim.health.hp) == vh1, "side-scoping: the enemy-planted ticker does NOT fire on the PLAYER's turn")
	# The ENEMY side ticks: now it fires.
	_pass_turn(m)                          # back to the enemy side
	_run_ticks(m, true)                    # enemy-side tick pass
	_check(vh1 - int(victim.health.hp) == 10, "side-scoping: it FIRES on the enemy (caster's) turn")

	# ==================================================================================
	# 3. stops_when_stunned — the Action gate pauses a ticker while its AUTHOR is stunned.
	# ==================================================================================
	# The gate is battle_manager:1225 (effect.source.classes["Action"] and effect.user.is_stunned).
	# Build the ability WITH the Action class (what authored_character derives from stops_when_stunned)
	# and drive execute_ticking_effect directly under both stun states — positive and negative on one
	# board.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; var foe = s["foes"][0]
	var ab_act := _mk(_spec([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "turns": 3, "first": "next", "stops_when_stunned": true, "then": payload}}], "enemy"), caster, true, true)
	_cast(caster, ab_act, [foe], m)
	var tick = _ticker_on(foe)
	_check(tick != null, "Action: the ticker landed on the foe")
	# Stun the AUTHOR (the caster). The gate reads effect.user, which is the caster.
	var stun = Effect.stun_effect(4)
	stun.set_source(caster.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(caster, m), caster, caster, stun, true)
	var fh0: int = int(foe.health.hp)
	m.execute_ticking_effect(tick)
	_check(int(foe.health.hp) == fh0, "Action: the ticker does NOT fire while its author is stunned")
	# Clear the stun; it fires again.
	for e in caster.get_effects_by_type(EffectType.Type.STUN):
		caster.effects.erase_effect(e)
	m.execute_ticking_effect(tick)
	_check(fh0 - int(foe.health.hp) == 10, "Action: it fires again once the author is no longer stunned")
	# The WIRING: stops_when_stunned is what authored_character turns into the Action class.
	_check(AuthoredCharacter._ability_stops_when_stunned([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "turns": 2, "stops_when_stunned": true, "then": payload}}]),
		"WIRING: stops_when_stunned true -> the ability carries the Action class")
	_check(not AuthoredCharacter._ability_stops_when_stunned([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "turns": 2, "stops_when_stunned": false, "then": payload}}]),
		"WIRING: stops_when_stunned false -> no Action class (positive control)")

	# ==================================================================================
	# 4. RECURRING DURATION IS AUTHOR-CONTROLLED — the invented hostile-placement cap is GONE.
	# ==================================================================================
	# REMOVED CAP (owner ruling: the Creator enforces no restriction the game itself lacks). A permanent
	# or long recurring planted on an ENEMY is per-round damage for one cast — a strong effect an APPROVER
	# weighs, not a rule the engine has (the roster ships permanent enemy-facing tickers, e.g. Mayuri's
	# drug rotation). So an enemy-facing recurring of ANY duration now VALIDATES and LANDS at exactly the
	# authored duration — no validator rejection, no runtime clamp. Own-side is the positive control.
	_check(_valid([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "turns": -1, "then": payload}}]),
		"REMOVED CAP: a PERMANENT recurring planted on an enemy VALIDATES (author-controlled duration)")
	_check(_valid([{"op": "apply", "to": "all_enemies",
		"effect": {"kind": "recurring", "turns": 6, "then": payload}}]),
		"REMOVED CAP: a 6-turn enemy-facing recurring VALIDATES (no duration cap)")
	_check(_valid([{"op": "apply", "to": "user",
		"effect": {"kind": "recurring", "turns": -1, "then": payload}}], "self"),
		"POSITIVE CONTROL: a PERMANENT recurring on your OWN side validates — always did, still does")
	# The RUNTIME half: execute() runs the blocks through _op_apply, and with the clamp removed a permanent
	# enemy-facing recurring must LAND permanent (dur -1), not be pulled to any cap.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foe = s["foes"][0]
	var ab_perm := _mk(_spec([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "turns": -1, "first": "next", "then": payload}}], "enemy"), caster, true)
	_cast(caster, ab_perm, [foe], m)
	var landed = _ticker_on(foe)
	_check(landed != null and int(landed.duration) == -1,
		"REMOVED CLAMP: a hostile permanent recurring LANDS permanent (dur=%s, want -1) — no runtime clamp" % [str(landed.duration) if landed else "<none>"])

	# ==================================================================================
	# 5. THE TWO-SITE last_turn_only FIX — no phantom reorder tile.
	# ==================================================================================
	# COLLECTOR: a last_turn_only ticker whose duration != 1 must NOT appear in get_ticking_effects
	# (that appearance IS the phantom draggable tile). A plain ticker on the same board is the
	# positive control. `ticks: 6` is a raw duration well above 1.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foe = s["foes"][0]
	var ab_lto := _mk(_spec([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "ticks": 6, "first": "next", "last_turn_only": true, "then": payload}}], "enemy"), caster, true)
	_cast(caster, ab_lto, [foe], m)
	var lto_eff = _ticker_on(foe)
	var ab_plain := _mk(_spec([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "ticks": 6, "first": "next", "then": payload}}], "enemy"), caster, true)
	_cast(caster, ab_plain, [s["foes"][1]], m)
	var collected = m.get_ticking_effects(foe, false)
	_check(not lto_eff in collected and lto_eff.duration != 1,
		"COLLECTOR: a last_turn_only ticker (duration %d) is NOT collected — no phantom tile" % lto_eff.duration)
	_check(m.get_ticking_effects(s["foes"][1], false).has(_ticker_on(s["foes"][1])),
		"COLLECTOR: a plain recurring on the same board IS collected (positive control)")
	# On its final tick (duration 1) it is collected — the effect still fires, once, at the end.
	lto_eff.duration = 1
	_check(m.get_ticking_effects(foe, false).has(lto_eff),
		"COLLECTOR: on its FINAL tick (duration 1) the last_turn_only ticker IS collected")

	# EXECUTOR: called directly, it does NOT run while duration != 1, and DOES on its final tick.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foe = s["foes"][0]
	var ab_lto2 := _mk(_spec([{"op": "apply", "to": "target",
		"effect": {"kind": "recurring", "ticks": 6, "first": "next", "last_turn_only": true, "then": payload}}], "enemy"), caster, true)
	_cast(caster, ab_lto2, [foe], m)
	var lto2 = _ticker_on(foe)
	fh0 = int(foe.health.hp)
	m.execute_ticking_effect(lto2)                # duration 6 != 1 -> guard returns early
	_check(int(foe.health.hp) == fh0, "EXECUTOR: a last_turn_only ticker does NOT fire before its final tick")
	lto2.duration = 1
	m.execute_ticking_effect(lto2)                # now it fires, once
	_check(fh0 - int(foe.health.hp) == 10, "EXECUTOR: it fires exactly once, on its final tick")

	# ==================================================================================
	# 6. stops_when_stunned CONSISTENCY — two recurring on one skill must agree.
	# ==================================================================================
	_check(not _valid([
			{"op": "apply", "to": "user", "effect": {"kind": "recurring", "turns": 2, "stops_when_stunned": true, "then": payload}},
			{"op": "apply", "to": "user", "effect": {"kind": "recurring", "turns": 2, "stops_when_stunned": false, "then": payload}}], "self"),
		"CONSISTENCY: two recurring with DIFFERENT stops_when_stunned on one skill are rejected")
	_check(_valid([
			{"op": "apply", "to": "user", "effect": {"kind": "recurring", "turns": 2, "stops_when_stunned": true, "then": payload}},
			{"op": "apply", "to": "user", "effect": {"kind": "recurring", "turns": 2, "stops_when_stunned": true, "then": payload}}], "self"),
		"CONSISTENCY: two recurring that AGREE validate (positive control)")

	# ==================================================================================
	# 7. THE RETIRED `Action` CHIP — no longer typeable on the class row; not exported to the editor.
	# ==================================================================================
	_check(not BlockValidator.validate_ability({"name": "X", "target": "enemy", "cost": {}, "cooldown": 0,
			"classes": ["Action"], "blocks": [{"op": "damage", "amount": 10, "to": "target"}], "requires": []}).is_empty(),
		"RETIRED: a hand-typed 'Action' class is rejected (use stops_when_stunned)")
	_check(not "Action" in BlockValidator.authorable_classes() and "Action" in Ability.CLASS_NAMES,
		"RETIRED: 'Action' is dropped from the editor palette but kept in the engine's class list")

	# ==================================================================================
	# 8. PROSE — "each turn" is the AUTHOR's turn; `first` and stops_when_stunned are reflected.
	# ==================================================================================
	_check(_prose_has({"kind": "recurring", "turns": 3, "first": "now", "then": payload}, "user", "On each of your turns") and
			_prose_has({"kind": "recurring", "turns": 3, "first": "now", "then": payload}, "user", "starting this turn"),
		"PROSE/now: 'On each of your turns ... starting this turn'")
	_check(_prose_has({"kind": "recurring", "turns": 3, "first": "next", "then": payload}, "user", "starting next turn"),
		"PROSE/next: reflects the delayed first tick ('starting next turn')")
	_check(_prose_has({"kind": "recurring", "turns": 3, "first": "now", "stops_when_stunned": true, "then": payload}, "user", "stunned"),
		"PROSE/stun: stops_when_stunned is surfaced in the sentence")

	# ==================================================================================
	# 9. BOT — TAG_REACTIVE + the payload's own tags; the hint counts amount x turns.
	# ==================================================================================
	var rec_blocks := [{"op": "apply", "to": "target", "effect": {"kind": "recurring", "turns": 3, "then": payload}}]
	_check(_tags_of(rec_blocks) & ScriptedAbility.TAG_REACTIVE != 0,
		"BOT/tags: a recurring is TAG_REACTIVE (Effect.trigger_effect is REACTIVE in the baker)")
	_check(_hint_of(rec_blocks) == 30,
		"BOT/hint: 10 per tick x 3 turns = 30 (not 10 — the v3 policy must not value it at one tick), got %d" % _hint_of(rec_blocks))

	# ==================================================================================
	# 10. SCHEMA SELF-CHECK — the recurring row folds into EFFECT_KINDS with no drift.
	# ==================================================================================
	var drift := BlockSchema.self_check()
	_check(drift.is_empty(), "SELF-CHECK: no table drift with the recurring row present (%s)" % str(drift))

	print("=== recurring probe: %d failure(s) ===" % fails)
	get_tree().quit(fails)
