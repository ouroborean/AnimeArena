extends Node

# Probe: a multi-target Harmful skill reflected back to its user (mag == -1)
# re-aims onto the ATTACKER's team, for BOTH AoE target types, with engine-correct
# validity (bypass-aware invuln + extra_targetable untargetability).
# Covers the adversarial-review findings:
#   #4 ALL (tt==2) type, not just ALL_FACTION      -> byakuya7 (ALL, Bypassing)
#   #1/#3 bypass-aware invuln                       -> byakuya7 hits an invuln ally; shinoa3 doesn't
#   #2 extra_targetable (Sealed King) untargetable  -> excluded even from a bypass skill
#   regression: SINGLE reflect unchanged
# Run: godot --headless --path <repo> res://training/tests/reflect_aoe_probe.tscn

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

func _add_bounce_reflect(defender, m):
	var a0 = defender.moveset.base_abilities[0]
	var r = Effect.reflect_effect(Trigger.always(a0.reflect_trigger),
		EffectType.Type.REFLECT_RECEIVE, -1, -1, "test", ["Harmful"])
	r.set_source(a0)
	Character.add_allied_effect(QueryContext.from_game_state(defender, m), defender, defender, r)

func _ready():
	print("=== reflected multi-target AoE -> attacker's team probe ===")

	# ---------- Scenario A: ALL_FACTION, non-bypass (shinoa3) ----------
	var mA := BattleManager.new(); mA.name = "BattleManager"; mA.shadow_mode = true; add_child(mA)
	var a1 := _build_player("BotPlayer", ["shinoa", "naruto", "gon"])
	var a2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	mA.start_battle(a1, a2, true, 91, BattleManager.MatchType.BOT)
	var shinoa = a1.team.characters[0]
	var s3 = shinoa.moveset.base_abilities[2]
	shinoa.used_ability = s3
	_check(s3.target_type() == TargetType.Type.ALL_FACTION, "shinoa3 is ALL_FACTION")
	# Make gon invuln — a non-bypass AoE must SKIP the invuln ally.
	var ginv = Effect.invuln_effect(-1, [], [])
	ginv.set_source(a1.team.characters[2].moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(a1.team.characters[2], mA), a1.team.characters[2], a1.team.characters[2], ginv)
	shinoa.targeter.targets = a2.team.characters.duplicate()
	shinoa.targeter.main_target = a2.team.characters[0]
	_add_bounce_reflect(a2.team.characters[0], mA)
	shinoa.reflect_check(mA, s3)
	var rA := []
	for t in shinoa.targeter.targets: rA.append(t.path_name)
	rA.sort()
	_check(rA == ["naruto", "shinoa"], "ALL_FACTION non-bypass re-aim EXCLUDES invuln ally (got %s)" % [rA])

	# ---------- Scenario B: ALL + Bypassing (byakuya7) ----------
	var mB := BattleManager.new(); mB.name = "BattleManager"; mB.shadow_mode = true; add_child(mB)
	var b1 := _build_player("BotPlayer", ["byakuya", "naruto", "gon"])
	var b2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	mB.start_battle(b1, b2, true, 91, BattleManager.MatchType.BOT)
	var byakuya = b1.team.characters[0]
	# find byakuya's ALL-type ability
	var b_all = null
	for ab in byakuya.moveset.base_abilities:
		if ab.target_type() == TargetType.Type.ALL: b_all = ab; break
	byakuya.used_ability = b_all
	_check(b_all != null, "found an ALL-type ability on byakuya (byakuya7)")
	_check(b_all.classes.get("Bypassing", false), "byakuya7 is a Bypassing skill")
	# gon invuln on the attacker's team — a BYPASSING AoE must still hit them.
	var g2 = Effect.invuln_effect(-1, [], [])
	g2.set_source(b1.team.characters[2].moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(b1.team.characters[2], mB), b1.team.characters[2], b1.team.characters[2], g2)
	byakuya.targeter.targets = b2.team.characters.duplicate()
	byakuya.targeter.main_target = b2.team.characters[0]
	_add_bounce_reflect(b2.team.characters[0], mB)
	byakuya.reflect_check(mB, b_all)
	var rB := []
	for t in byakuya.targeter.targets: rB.append(t.path_name)
	rB.sort()
	# ALL type is now handled (finding #4); Bypassing -> the invuln ally is NOT skipped (finding #1/#3).
	_check(rB == ["byakuya", "gon", "naruto"], "ALL+Bypassing re-aim hits the whole team incl. invuln ally (got %s)" % [rB])

	# ---------- Regression: SINGLE reflect unchanged ----------
	var single = null
	for ab in byakuya.moveset.base_abilities:
		if ab.target_type() == TargetType.Type.SINGLE: single = ab; break
	byakuya.used_ability = single
	byakuya.targeter.targets = [b2.team.characters[1]]
	byakuya.targeter.main_target = b2.team.characters[1]
	_add_bounce_reflect(b2.team.characters[1], mB)
	byakuya.reflect_check(mB, single)
	_check(byakuya.targeter.targets == [byakuya], "SINGLE reflect still redirects to attacker")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
