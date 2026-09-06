extends Node

# Special Beam Cannon + Hellzone Grenade IGNORE the default 100 damage-received cap.
#
# The cap lives in deal_ability_damage: `receive_cap = target.get_damage_cap_receive()` (default 100),
# applied UNCONDITIONALLY, so a stack-scaled payoff was silently clipped to 100. piccolo1/piccolo2 now
# set `ignore_damage_cap` (abilities_data.json), and deal_ability_damage skips ONLY the default-100 cap
# for such abilities — an EXPLICIT lower receive cap (Yoh's damage_cap_receive) still applies.
#
# Measured via a large SHIELD on the target: the cap is applied before check_damage_against_shielding,
# and Piercing (SBC) as well as Normal (Hellzone) both pass through shield, so shield loss == the exact
# post-cap damage.
#   godot --headless --path <repo> res://training/tests/piccolo_damage_cap_probe.tscn

var fails := 0

func _check(c, l, detail := ""):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l + ("  (" + detail + ")" if detail != "" else ""))

func _build(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _shield(c) -> int:
	var s = 0
	for e in c.get_shield_effects():
		s += int(e.mag)
	return s

func _hit(piccolo, ability, amount, E, dtype) -> int:
	# Raw pass through the shared damage pipeline; shield loss == post-cap damage.
	var before = _shield(E)
	ability.user = piccolo
	piccolo.deal_ability_damage(ability, amount, E, dtype)
	return before - _shield(E)

func _ready():
	print("=== piccolo damage-cap probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Picc", ["piccolo", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["killua", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var picc = p1.team.characters[0]
	var E = p2.team.characters[0]
	var PIER = DamageType.Type.PIERCING
	var NORM = DamageType.Type.NORMAL
	var sbc = picc.moveset.base_abilities[0]      # Special Beam Cannon (ignore_damage_cap)
	var hellzone = picc.moveset.base_abilities[1] # Hellzone Grenade   (ignore_damage_cap)
	var regen = picc.moveset.base_abilities[2]    # Regeneration       (NOT flagged — control)

	_check(sbc.ignore_damage_cap and hellzone.ignore_damage_cap, "[data] SBC + Hellzone carry ignore_damage_cap")
	_check(not regen.ignore_damage_cap, "[data] Regeneration does NOT (control)")

	# Big shield to absorb (and thereby measure) the full post-cap hit.
	var qc = QueryContext.from_game_state(E, m)
	var big = Effect.shield_effect(4000, -1); big.set_source(regen)
	Character.add_allied_effect(qc, E, E, big)

	# 1. SBC (flagged) at 125 raw -> lands the full 125 (cap removed).
	_check(_hit(picc, sbc, 125, E, PIER) == 125, "[FIX] Special Beam Cannon deals its full 125 (uncapped)")
	# 2. Control: an UNFLAGGED ability at 125 is still clipped to 100.
	_check(_hit(picc, regen, 125, E, PIER) == 100, "[control] an ability WITHOUT the flag is still capped at 100")
	# 3. Hellzone (flagged, Normal) at 130 -> full 130.
	_check(_hit(picc, hellzone, 130, E, NORM) == 130, "[FIX] Hellzone Grenade deals its full 130 (uncapped)")
	# 4. An EXPLICIT lower receive cap (Yoh-style, 20) STILL applies even to a flagged skill.
	var ycap = Effect.damage_cap_receive(20, 6); ycap.set_source(regen)
	Character.add_hostile_effect(QueryContext.from_game_state(E, m), picc, E, ycap)
	_check(_hit(picc, sbc, 125, E, PIER) == 20, "[scope] SBC still respects an EXPLICIT receive cap (20)")
	for e in E.effects.get_effects_by_type(EffectType.Type.DAMAGE_CAP_RECEIVE): E.effects.erase_effect(e)

	# 5. End-to-end: the REAL SBC payoff at 5 stacks (25 + 20*5 = 125) lands uncapped through resolve_damage.
	picc.targeter.targets = [picc]; picc.targeter.main_target = picc; picc.used_ability = sbc
	sbc.execute(picc, m)                                    # begin channel
	var mark = picc.has_effect("Special Beam Cannon", EffectType.Type.MARK, picc)
	_check(mark != null, "[e2e] channel started")
	if mark != null: mark.stacks = 5
	var s0 = _shield(E)
	picc.targeter.targets = [E]; picc.targeter.main_target = E; picc.used_ability = sbc
	sbc.execute(picc, m)                                    # re-use -> payoff
	_check(s0 - _shield(E) == 125, "[e2e] real 5-stack payoff lands 125 through resolve_damage (dealt %d)" % (s0 - _shield(E)))

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
