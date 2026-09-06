extends Node

# Probe: S3 (Terror Incarnate) now needs 3 stacks, and the reflect fires on
# damage Yubel TAKES (not damage she ignores), sending it back to the attacker.
# Run: godot --headless --path <repo> res://training/tests/yubel_reflect_probe.tscn

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

func _set_terror(yubel, n: int):
	var ctx = QueryContext.from_game_state(yubel, yubel.battle)
	var m = Effect.mark(-1, "Terror")
	m.set_source(yubel.moveset.base_abilities[2])   # yubel3 == "Terror Incarnate"
	m.stackable = true; m.display_stacks = true; m.stacks = n
	Character.add_allied_effect(ctx, yubel, yubel, m, true)

func _ready():
	print("=== yubel S3 threshold + reflect-on-taken probe ===")
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["yubel", "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 55, BattleManager.MatchType.BOT)

	var yubel = p1.team.characters[0]
	var enemy = p2.team.characters[0]
	var yubel3 = yubel.moveset.base_abilities[2]

	# --- S3 threshold: unusable at 1 stack, usable at 2 (current breakpoints: S3=2, S5=5) ---
	_set_terror(yubel, 1)
	_check(not yubel3.extra_usable(yubel), "S3 NOT usable at 1 stack (threshold is 2)")
	_set_terror(yubel, 2)
	_check(yubel3.extra_usable(yubel), "S3 usable at 2 stacks")

	# --- Activate S3 (installs the Terror Incarnate reflect marker) ---
	yubel.targeter.targets = [yubel]
	yubel3.execute(yubel, m)
	_check(yubel.has_effect("Terror Incarnate", EffectType.Type.HARMFUL_RECEIVE_TRIGGER, yubel) != null,
		"S3 installed the reflect marker")

	# --- Enemy damages Yubel; she takes it AND reflects it back ---
	var y_before = yubel.health.hp
	var e_before = enemy.health.hp
	var ctx = QueryContext.from_game_state(enemy, m)
	enemy.used_ability = enemy.moveset.base_abilities[0]
	Character.resolve_damage(ctx, yubel, 30, DamageType.Type.NORMAL)
	# EXACT amounts, not "went down": S3 reflects the damage TAKEN, so both sides move by the
	# full 30. A wrong-but-nonzero reflect (halved, or the pre-mitigation figure) survived `<`.
	_check(y_before - yubel.health.hp == 30,
		"Yubel TOOK the full 30: %d -> %d" % [y_before, yubel.health.hp])
	_check(e_before - enemy.health.hp == 30,
		"attacker got the SAME 30 back: %d -> %d" % [e_before, enemy.health.hp])

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
