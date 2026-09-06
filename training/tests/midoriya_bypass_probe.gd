extends Node
# Verifies Midoriya's "Faux 100%" actually makes his skills BYPASS enemy Invulnerability (so the added
# tooltip clause is truthful), and that the effect's tooltip string now advertises it.
#   godot --headless --path <repo> res://training/tests/midoriya_bypass_probe.tscn

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
	var p1 := _build_player("BotPlayer", ["midoriya", "naruto", "sakura"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "gray"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "mid": p1.team.characters[0], "foes": p2.team.characters}

func _exec(m, caster, ab, targets):
	caster.used_ability = ab
	caster.targeter.targets = targets.duplicate()
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)

func _invuln(target, m, dur):
	var inv = Effect.invuln_effect(dur)
	inv.set_source(target.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(target, m), target, target, inv)

const AUT := EffectType.Type.ACTION_USE_TRIGGER

func _ready():
	print("=== MIDORIYA Faux 100% bypass probe ===")
	var s = _fresh(); var m = s["m"]; var mid = s["mid"]
	var foe = s["foes"][0]; var foe2 = s["foes"][1]
	var faux_ab = mid.moveset.base_abilities[4]     # midoriya5 "Faux 100%"
	var blackwhip = mid.moveset.base_abilities[0]    # midoriya1

	# Baseline: WITHOUT Faux 100%, Blackwhip cannot target an Invulnerable enemy.
	_invuln(foe, m, 10)
	m.reset_character_targeted()
	blackwhip.target(mid, m)
	_check(not foe.targeted, "baseline: without Faux 100%, Blackwhip cannot target the Invulnerable enemy")

	# Install the permanent Faux 100% effect (cast midoriya5 on a different enemy).
	_exec(m, mid, faux_ab, [foe2])
	var eff = mid.has_effect("Faux 100%", AUT, mid)
	_check(eff != null, "Faux 100% installed as a permanent ACTION_USE_TRIGGER effect")
	var tip := ""
	if eff != null and eff.description is Callable:
		tip = str(eff.description.call(eff))
	_check("Bypass" in tip, "Faux 100% tooltip now advertises the bypass -> \"" + tip + "\"")

	# With Faux 100% active, Blackwhip CAN now target the Invulnerable enemy (bypass targeting).
	m.reset_character_targeted()
	blackwhip.target(mid, m)
	_check(foe.targeted, "with Faux 100%: Blackwhip can target the Invulnerable enemy (bypass)")

	# End-to-end through the real path: _drop_invuln_targets re-runs target() (bypassing), keeps the
	# invuln foe, and the hit lands. (Without bypass the skill would fizzle on the dropped target.)
	var hp0 = int(foe.health.hp)
	mid.used_ability = blackwhip
	mid.targeter.targets = [foe]
	mid.targeter.main_target = foe
	m.execute_ability(blackwhip)
	_check(hp0 - int(foe.health.hp) == 10, "with Faux 100%: Blackwhip's damage lands THROUGH Invulnerability (survives _drop_invuln_targets)")

	# ---- EFFECT APPLICATION through Invulnerability (the actual bug: bypass reached targeting + damage,
	#      but the add_hostile_effect calls never got it, so stun/vulnerability fizzled on Invuln targets) ----
	# Fresh battle A: WITHOUT Faux, Blackwhip's execute() onto an Invuln foe -> its stun + vuln are BLOCKED.
	var a = _fresh(); var am = a["m"]; var amid = a["mid"]; var afoe = a["foes"][0]
	var abw = amid.moveset.base_abilities[0]
	_invuln(afoe, am, 10)
	_exec(am, amid, abw, [afoe])
	_check(not amid.grants_skill_bypass(), "control: grants_skill_bypass() is false with no bypass source")
	_check(afoe.is_invuln(abw), "control: foe stays Invulnerable to a non-bypassing Midoriya skill")
	_check(afoe.get_effects_by_type(EffectType.Type.STUN).size() == 0, "control: without Faux, Blackwhip's STUN is BLOCKED by Invulnerability")
	_check(afoe.get_effects_by_type(EffectType.Type.VULNERABILITY).size() == 0, "control: without Faux, Blackwhip's VULNERABILITY is BLOCKED by Invulnerability")

	# Fresh battle B: WITH Faux 100%, the SAME execute() now lands stun + vulnerability THROUGH Invulnerability.
	var b = _fresh(); var bm = b["m"]; var bmid = b["mid"]; var bfoe = b["foes"][0]; var bfoe2 = b["foes"][1]
	var bbw = bmid.moveset.base_abilities[0]; var bfaux = bmid.moveset.base_abilities[4]
	_invuln(bfoe, bm, 10)
	_exec(bm, bmid, bfaux, [bfoe2])                     # install permanent Faux 100%
	_check(bmid.grants_skill_bypass(), "grants_skill_bypass() is true while Faux 100% is active")
	_check(not bfoe.is_invuln(bbw), "with Faux: foe.is_invuln(Blackwhip) == false (skill pierces)")
	_exec(bm, bmid, bbw, [bfoe])
	_check(bfoe.get_effects_by_type(EffectType.Type.STUN).size() >= 1, "with Faux 100%: Blackwhip's STUN lands THROUGH Invulnerability")
	_check(bfoe.get_effects_by_type(EffectType.Type.VULNERABILITY).size() >= 1, "with Faux 100%: Blackwhip's VULNERABILITY lands THROUGH Invulnerability")

	# Regression: the Tsubaki (Kusarigama) source shares the exact same is_invuln hook — still pierces.
	var km = Effect.mark(10); km.name_override = "Tsubaki Mode: Kusarigama"; km.set_source(abw)
	Character.add_allied_effect(QueryContext.from_game_state(amid, am), amid, amid, km)
	_check(amid.grants_skill_bypass(), "regression: a Kusarigama-marked character still grants bypass")
	_check(not afoe.is_invuln(abw), "regression: Kusarigama wielder pierces Invulnerability via the same hook")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
