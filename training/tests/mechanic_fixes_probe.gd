extends Node

# Regression probe for three mechanic fixes.
#   godot --headless --path <repo> res://training/tests/mechanic_fixes_probe.tscn
#
# 1. Nezuko's cleanse matches on the SOURCE ABILITY's classes
#    (effect_storage_component.cleanse_hostile_afflictions -> has_ability_class("Affliction", eff.source)).
#    Shinra's 5-tick affliction is sourced to base_abilities[0] (Ignition: Shinra) by BOTH shinra2 and
#    shinra3, so Ignition is the ability that must carry the class — not the skill that applies it.
# 2. sasuke5's counter-stun runs at duration 3: it lands during the ENEMY's turn, so a duration-2 stun
#    expires before they ever reach a turn they could have acted on.
# 3. gatomon3 carries Energy + Strategic.

var fails := 0

func _check(c, l):
	if c: print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _cast(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.used_ability = ab
	ab.execute(caster, m)
	return ab

func _ready():
	print("=== mechanic fixes probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"; m.shadow_mode = true
	add_child(m)
	var p1 = _build("BotPlayer", ["shinra", "sasuke", "gatomon"], false)
	var p2 = _build("BotEnemy", ["nezuko", "naruto", "gray"], true)
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	var shinra = p1.team.characters[0]
	var sasuke = p1.team.characters[1]
	var gatomon = p1.team.characters[2]
	var nezuko = p2.team.characters[0]
	var ally = p2.team.characters[1]

	# ---- 1. the class is on the SOURCE ability, and Nezuko's cleanse now sees it ----------------
	_check("Affliction" in shinra.moveset.base_abilities[0].classes_list(),
		"Ignition: Shinra carries the Affliction class") if shinra.moveset.base_abilities[0].has_method("classes_list") else \
	_check(shinra.moveset.base_abilities[0].classes.get("Affliction", false),
		"Ignition: Shinra carries the Affliction class")

	_cast(m, shinra, 0, [shinra])                      # Ignition: Shinra (self mark)
	_cast(m, shinra, 1, [ally])                        # Rapid Kick -> applies the 5 affliction
	var dot = ally.has_effect("Ignition: Shinra", EffectType.Type.DAMAGE, shinra)
	_check(dot != null, "Rapid Kick applied the affliction DoT, sourced to Ignition")
	if dot != null:
		_check(dot.source == shinra.moveset.base_abilities[0],
			"...and its SOURCE really is Ignition (base_abilities[0]), not Rapid Kick")
		_check(dot.cleansable, "...and it is cleansable at all (a cleanse-proof DoT would never clear)")

	# Nezuko heals an ally -> cleanse_hostile_afflictions on that ally
	ally.effects.cleanse_hostile_afflictions(ally)
	_check(ally.has_effect("Ignition: Shinra", EffectType.Type.DAMAGE, shinra) == null,
		"Nezuko's cleanse REMOVES the affliction (this is the fix)")

	# ---- 2. sasuke5's counter-stun duration ------------------------------------------------------
	var wire = sasuke.moveset.base_abilities[4]
	var src := FileAccess.open("res://abilities/sasuke5.gd", FileAccess.READ).get_as_text()
	_check(src.contains("Effect.stun_effect(3)"), "Shadow Shuriken Wire Trap stuns at duration 3")
	_check(not src.contains("Effect.stun_effect(2)"), "...and no duration-2 stun remains in the file")

	# ---- 3. gatomon3 classes ---------------------------------------------------------------------
	var digi = gatomon.moveset.base_abilities[2]
	_check(digi.classes.get("Energy", false), "Gatomon Digivolve carries Energy")
	_check(digi.classes.get("Strategic", false), "Gatomon Digivolve carries Strategic")
	_check(digi.classes.get("Instant", false), "...and still carries Instant")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
