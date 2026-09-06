extends Node

# Verify: (1) Ripcord Pull's +5 damage boost does NOT apply to Denji's Bleed
# (direct or DoT), but DOES apply to non-Bleed; (2) Devil Transformation now
# costs 1 Random.
#   godot --headless --path <repo> res://training/tests/denji_tweaks_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _build_player(u, names):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy = (u == "BotEnemy")
	for n in names: p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _ready():
	print("=== denji tweaks probe ===")
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 = _build_player("BotPlayer", ["denji", "naruto", "gon"])
	var p2 = _build_player("BotEnemy", ["eren", "misaka", "gray"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	var denji = p1.team.characters[0]
	var foe = p2.team.characters[0]

	# --- Devil Transformation cost = 1 Random ---
	var transform = denji.moveset.base_abilities[2]   # denji3 = Devil Transformation
	_check(transform.ability_name == "Devil Transformation", "denji3 is Devil Transformation")
	var tcost = transform.cost()
	_check(int(tcost.get(Energy.Type.RANDOM, 0)) == 1, "Devil Transformation costs 1 Random (got %s)" % tcost)

	# --- Ripcord Pull boost excludes Bleed ---
	var ripcord = denji.moveset.base_abilities[5]     # denji6 = Ripcord Pull
	ripcord.execute(denji, m)   # applies the +5 damage-mod (BLEED excluded)
	# The DAMAGE_MOD carries BLEED in exclusion_targets — get_true_damage skips
	# the boost when damage_type is in exclusion_targets (ability_component.gd:565).
	var mods = denji.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD)
	_check(mods.size() == 1, "one Ripcord damage-mod on Denji")
	var boost = mods[0]
	_check(DamageType.Type.BLEED in boost.exclusion_targets,
		"Ripcord boost excludes BLEED (exclusion_targets=%s)" % [boost.exclusion_targets])
	_check(boost.class_targets.is_empty(),
		"Ripcord boost still applies to all OTHER types (no class_targets whitelist)")

	# get_true_damage is the pure offense calc the DAMAGE_MOD gates (source=null
	# skips the source-based branches). Base 10 from Denji:
	var normal_out = ripcord.get_true_damage(denji, foe, 10, null, DamageType.Type.NORMAL)
	var pierce_out = ripcord.get_true_damage(denji, foe, 10, null, DamageType.Type.PIERCING)
	var bleed_out = ripcord.get_true_damage(denji, foe, 10, null, DamageType.Type.BLEED)
	_check(normal_out == 15, "Normal boosted (10 -> %d, expect 15)" % normal_out)
	_check(pierce_out == 15, "Piercing boosted (10 -> %d, expect 15)" % pierce_out)
	_check(bleed_out == 10, "Bleed NOT boosted (10 -> %d, expect 10)" % bleed_out)

	# Second stack: non-Bleed climbs +5, Bleed stays flat.
	ripcord.execute(denji, m)
	_check(ripcord.get_true_damage(denji, foe, 10, null, DamageType.Type.NORMAL) == 20,
		"Normal is 20 after 2 Ripcord stacks")
	_check(ripcord.get_true_damage(denji, foe, 10, null, DamageType.Type.BLEED) == 10,
		"Bleed still 10 after 2 Ripcord stacks")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
