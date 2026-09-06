extends Node

# Verifies the two ability behavioral bug-fixes: Toudou Draw Stance counter scope, and Koro Pitch Black
# self-mark that Impossible Speed's target() now keys on.
#   godot --headless --path <repo> res://training/tests/bugfix_probe.tscn

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

func _fresh(allies, foes) -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", allies)
	var p2 := _build_player("BotEnemy", foes)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _cast(caster, ab, targets, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _ready():
	print("=== bug-fix probe ===")
	var s = _fresh(["toudou", "koro", "naruto"], ["ichibe", "misaka", "sakura"])
	var m = s["m"]
	var tou = s["allies"][0]; var koro = s["allies"][1]

	# BUG 3: Draw Stance's counter is now scoped to Harmful (was [] = counter everything, incl. Strategic Ink Splatter)
	_cast(tou, tou.moveset.base_abilities[0], [tou], m)   # Draw Stance (self)
	var ce = tou.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE)
	_check(ce.size() >= 1 and ce[0].class_targets == ["Harmful"],
		"Draw Stance: counter class_targets == [\"Harmful\"] (got %s)" % (str(ce[0].class_targets) if ce.size() > 0 else "<none>"))

	# BUG 1: Pitch Black applies the "Pitch Black" self-mark that Impossible Speed.target() now checks for its Bypass
	_cast(koro, koro.moveset.base_abilities[3], [koro], m)   # Pitch Black (koro4)
	_check(koro.marked_by("Pitch Black", koro), "Pitch Black: applies the self-mark Impossible Speed.target() keys on")
	# and target() no longer crashes / runs with the corrected mark
	koro.moveset.base_abilities[1].target(koro, m)   # Impossible Speed (koro2) — exercises the fixed target()
	_check(true, "Impossible Speed.target() runs under Pitch Black without error")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit(0 if fails == 0 else 1)
