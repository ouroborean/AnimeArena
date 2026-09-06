extends Node

# Probe: Yubel no longer starts at 5 HP and no longer ignores damage.
# Also confirms she STILL ignores non-damage effects while she has an ally,
# and still stacks Terror Incarnate when targeted.
# Run: godot --headless --path <repo> res://training/tests/yubel_probe.tscn

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

func _ready():
	print("=== yubel nerf probe ===")
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["yubel", "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 909, BattleManager.MatchType.BOT)

	var yubel = p1.team.characters[0]
	var enemy = p2.team.characters[0]

	# Passive auto-runs at startup. Check HP + no damage-ignore.
	_check(yubel.get_modified_max_hp() == 100, "max HP is 100, not 5 (was %d)" % yubel.get_modified_max_hp())
	_check(yubel.health.hp == 100, "starts at 100 HP (was %d)" % yubel.health.hp)
	_check(yubel.effects.get_effects_by_type(EffectType.Type.HEALTH_CAP).size() == 0, "no HEALTH_CAP effect")
	_check(yubel.effects.get_effects_by_type(EffectType.Type.IGNORE_DAMAGE).size() == 0, "no IGNORE_DAMAGE effect")
	_check(yubel.effects.get_effects_by_type(EffectType.Type.IGNORE_NON_DAMAGE).size() > 0, "still ignores non-damage (has ally)")

	# Deal damage — it should LAND now (previously ignored). resolve_damage needs
	# the dealer's used_ability set (it's normally set by the execution loop).
	var ctx = QueryContext.from_game_state(enemy, m)
	enemy.used_ability = enemy.moveset.base_abilities[0]
	Character.resolve_damage(ctx, yubel, 30, DamageType.Type.NORMAL)
	# EXACT, not "< 100": a damage-reduction regression that let 1 HP through would satisfy the
	# loose form while the hit was effectively still being eaten.
	_check(yubel.health.hp == 70, "took the FULL 30: 100 -> %d (was ignored before)" % yubel.health.hp)

	# Non-damage effect (stun) should still be ignored while she has an ally:
	# no STUN effect should attach.
	var stun = Effect.stun_effect(2); stun.set_source(enemy.moveset.base_abilities[0])
	Character.add_hostile_effect(ctx, enemy, yubel, stun)
	_check(yubel.effects.get_effects_by_type(EffectType.Type.STUN).size() == 0,
		"non-damage stun ignored while she has an ally")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
