extends Node

# JADEN'S FUSIONS SURVIVE A HELPFUL-CLEANSE.
#
# Bug: a Helpful buff-strip (Inuyasha's Iron Reaver Soul Stealer -> cleanse_all_ally_effects) removes the
# base HERO's TICKING_TRIGGER (cleansable, dur 5), so the fusion gates — which read that trigger — grayed
# the fusion out even though its ABILITY_SWAP (cleansable=false) still holds the slot. Fix: the fusion
# extra_usable checks now read the ingredient ABILITY_SWAP instead of the TICKING_TRIGGER.
#   godot --headless --path <repo> res://training/tests/jaden_fusion_cleanse_probe.tscn

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

func _has(j, name, type):
	return j.has_effect(name, type, j) != null

func _ready():
	print("=== jaden fusion + helpful-cleanse probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Jaden", ["jaden", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["inuyasha", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var jaden = p1.team.characters[0]
	var breaker = p2.team.characters[0]   # stands in for Inuyasha's cleanse source
	var TT = EffectType.Type.TICKING_TRIGGER
	var SW = EffectType.Type.ABILITY_SWAP

	# --- Bring up Avian (index 0) + Bubbleman (index 3), enabling Mariner (index 7) ---
	var avian = jaden.moveset.base_abilities[0]
	var bubbleman = jaden.moveset.base_abilities[3]
	var mariner = jaden.moveset.base_abilities[7]
	for ab in [avian, bubbleman]:
		jaden.targeter.targets = [jaden]
		jaden.targeter.main_target = jaden
		jaden.used_ability = ab
		ab.execute(jaden, m)

	_check(_has(jaden, "Elemental HERO Avian", TT) and _has(jaden, "Elemental HERO Bubbleman", TT),
		"[setup] both ingredient TICKING_TRIGGERs present")
	_check(_has(jaden, "Elemental HERO Avian", SW) and _has(jaden, "Elemental HERO Bubbleman", SW),
		"[setup] both ingredient ABILITY_SWAPs present")
	_check(mariner.extra_usable(jaden), "[setup] Mariner is usable before the cleanse")

	# --- Helpful cleanse (Inuyasha's Iron Reaver mechanism) on Jaden ---
	jaden.effects.cleanse_all_ally_effects(jaden, breaker)

	# Triggers are cleansable -> stripped; swaps are non-cleansable -> survive.
	_check(not _has(jaden, "Elemental HERO Avian", TT) and not _has(jaden, "Elemental HERO Bubbleman", TT),
		"[cleanse] ingredient TICKING_TRIGGERs were stripped (cleansable)")
	_check(_has(jaden, "Elemental HERO Avian", SW) and _has(jaden, "Elemental HERO Bubbleman", SW),
		"[cleanse] ingredient ABILITY_SWAPs SURVIVE (non-cleansable)")

	# THE FIX: the fusion is still usable because the gate now reads the surviving swap.
	_check(mariner.extra_usable(jaden), "[FIX] Mariner is STILL usable after the Helpful cleanse")

	# Guard: casting the fusion consumes the ingredient swaps, so it can't be re-fused.
	jaden.targeter.targets = [jaden]
	jaden.targeter.main_target = jaden
	jaden.used_ability = mariner
	mariner.execute(jaden, m)
	_check(not _has(jaden, "Elemental HERO Avian", SW) and not _has(jaden, "Elemental HERO Bubbleman", SW),
		"[guard] casting Mariner consumed the ingredient swaps")
	_check(not mariner.extra_usable(jaden), "[guard] Mariner is no longer usable after being cast")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
