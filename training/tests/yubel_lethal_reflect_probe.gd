extends Node

# Probe: Yubel's reflect (S3 Terror Incarnate / S5 Ultimate Nightmare) must fire on
# the hit that KILLS her. The damage call runs die() -> cleanse_death_effects(),
# which erases every effect she cast — including the reflect markers — so a
# post-damage lookup found nothing and the killing blow went unreflected.
# Run: godot --headless --path <repo> res://training/tests/yubel_lethal_reflect_probe.tscn

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

func _fresh() -> Array:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["yubel", "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 606, BattleManager.MatchType.BOT)
	return [m, p1, p2]

# Install S3 (bounce to attacker) or S5 (whole enemy team) on Yubel.
func _arm(yubel, m, use_s5: bool):
	var idx := 4 if use_s5 else 2
	var skill = yubel.moveset.base_abilities[idx]
	if not use_s5:
		# S3 needs its Terror Incarnate stack mark present (>=2) to install.
		var ctx0 = QueryContext.from_game_state(yubel, m)
		var mk = Effect.mark(-1, "Terror")
		mk.set_source(yubel.moveset.base_abilities[2])
		mk.stackable = true; mk.display_stacks = true; mk.stacks = 2
		Character.add_allied_effect(ctx0, yubel, yubel, mk, true)
	yubel.targeter.targets = [yubel]
	yubel.used_ability = skill
	skill.execute(yubel, m)

func _hit(attacker, yubel, m, amount: int):
	var ctx = QueryContext.from_game_state(attacker, m)
	attacker.used_ability = attacker.moveset.base_abilities[0]
	Character.resolve_damage(ctx, yubel, amount, DamageType.Type.NORMAL)

func _ready():
	print("=== Yubel lethal-hit reflect probe ===")

	# ---------- A: S3, NON-lethal (regression guard) ----------
	var a = _fresh(); var mA = a[0]; var yA = a[1].team.characters[0]; var eA = a[2].team.characters[0]
	_arm(yA, mA, false)
	var before = eA.health.hp
	_hit(eA, yA, mA, 30)
	_check(not yA.dead, "A setup: Yubel survived a 30 hit")
	_check(eA.health.hp == before - 30, "A non-lethal reflect still works: attacker %d -> %d" % [before, eA.health.hp])

	# ---------- B: S3, LETHAL (the reported bug) ----------
	var b = _fresh(); var mB = b[0]; var yB = b[1].team.characters[0]; var eB = b[2].team.characters[0]
	_arm(yB, mB, false)
	yB.health.hp = 20
	var eB_before = eB.health.hp
	_hit(eB, yB, mB, 60)          # lethal: kills Yubel outright
	_check(yB.dead, "B setup: the hit KILLED Yubel")
	_check(eB.health.hp == eB_before - 60,
		"B LETHAL hit is reflected to the attacker: %d -> %d (expected %d)" % [eB_before, eB.health.hp, eB_before - 60])

	# ---------- C: S5, LETHAL — whole enemy team ----------
	var c = _fresh(); var mC = c[0]; var yC = c[1].team.characters[0]; var teamC = c[2].team.characters
	_arm(yC, mC, true)
	yC.health.hp = 15
	var hp_before := []
	for ch in teamC: hp_before.append(ch.health.hp)
	_hit(teamC[0], yC, mC, 50)
	_check(yC.dead, "C setup: the hit KILLED Yubel")
	var all_hit := true
	var report := []
	for i in range(teamC.size()):
		report.append("%s %d->%d" % [teamC[i].path_name, hp_before[i], teamC[i].health.hp])
		if teamC[i].health.hp != hp_before[i] - 50:
			all_hit = false
	_check(all_hit, "C LETHAL hit reflects to the WHOLE enemy team: %s" % [", ".join(report)])

	# ---------- D: no reflect armed -> nothing happens ----------
	var d = _fresh(); var mD = d[0]; var yD = d[1].team.characters[0]; var eD = d[2].team.characters[0]
	yD.health.hp = 20
	var eD_before = eD.health.hp
	_hit(eD, yD, mD, 60)
	_check(yD.dead, "D setup: Yubel died with no reflect armed")
	_check(eD.health.hp == eD_before, "D unarmed Yubel reflects nothing (attacker stays %d)" % eD.health.hp)

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
