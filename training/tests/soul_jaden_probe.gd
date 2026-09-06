extends Node

# Soul Evans + Jaden Yuki probe (patch 2026-08-02, phases 2 and 3).
#
# WHAT IS UNDER TEST, and why a compile proves none of it:
#   JADEN - Avian / Burstinatrix / Bubbleman no longer grant a Shield, and the Shield WAS the token
#   every fusion gate looked its ingredients up by. All four fusions were repointed onto the base
#   HERO's TICKING_TRIGGER. A half-done repoint is a permanently greyed-out button: no error, no
#   log, compiles and renders perfectly. Every fusion is therefore asserted POSITIVE-first (it
#   lights up with its two ingredients) before the negative (it is dark without them).
#
#   SOUL - Nightmare Wavelength's recoil now goes to the WIELDER INSTEAD of Soul (Soul takes 0),
#   Nightmare Sonata's boost moved onto the enemy hit and dropped 20 -> 10, Sonata gained a
#   3-turn Affliction tick that lands on the cast turn, and Scythe Transformation's bonus grows
#   +5 PER DAMAGE INSTANCE Soul lands on the wielder.
#
#   godot --headless --path <repo> res://training/tests/soul_jaden_probe.tscn

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build_player(u, names):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	var is_enemy = (u == "BotEnemy")
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _fill_energy(p):
	for colour in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		p.team.energy.pool[colour] = 20

func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)

func _find(team, path):
	for c in team.characters:
		if c.path_name == path:
			return c
	return null

# The fusion gates are read off the ability object, not the (swapped) moveset slot.
func _skill(c, idx):
	return c.moveset.base_abilities[idx]

func _clear_all(c):
	for eff in c.effects._effects.duplicate():
		c.effects.erase_effect(eff)


func _ready():
	print("=== Soul + Jaden probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["soul", "jaden", "gon"])
	var p2 = _build_player("BotEnemy", ["gon", "gray", "naruto"])
	m.start_battle(p1, p2, true, 20260802, BattleManager.MatchType.BOT)
	_fill_energy(p1)
	_fill_energy(p2)
	for c in p1.team.characters + p2.team.characters:
		c.refresh()

	var soul = _find(p1.team, "soul")
	var jaden = _find(p1.team, "jaden")
	var ally = _find(p1.team, "gon")          # Soul's wield target (Maka is absent, so any ally)
	var foe = p2.team.characters[0]
	_check(soul != null and jaden != null and ally != null, "[setup] Soul, Jaden and a wield target are on the board")

	# =====================================================================================
	# JADEN 1 - the base HEROes no longer grant a Shield, but still plant their ticker.
	# =====================================================================================
	print("-- Jaden: base HERO Shields are gone, the ticker is the new token --")
	for pair in [[0, "Elemental HERO Avian"], [1, "Elemental HERO Burstinatrix"], [3, "Elemental HERO Bubbleman"]]:
		_clear_all(jaden)
		_cast(jaden, _skill(jaden, pair[0]), [jaden], m)
		_check(jaden.effects.has_effect(pair[1], EffectType.Type.TICKING_TRIGGER, jaden) != null,
			"POSITIVE: %s still plants its TICKING_TRIGGER (the fusion token)" % pair[1])
		_check(jaden.effects.has_effect(pair[1], EffectType.Type.SHIELD, jaden) == null,
			"...and grants NO Shield any more" % [])
	# Clayman is the deliberate asymmetry - it keeps its Shield.
	_clear_all(jaden)
	_cast(jaden, _skill(jaden, 2), [jaden], m)
	_check(jaden.effects.has_effect("Elemental HERO Clayman", EffectType.Type.SHIELD, jaden) != null,
		"[control] Clayman DOES still grant a Shield (only Avian/Burstinatrix/Bubbleman lost theirs)")

	# =====================================================================================
	# JADEN 2 - all four fusion gates, each asserted lit-then-dark, then consumption.
	# Recipe: 5 = Avian(0) + Burstinatrix(1); 6 = Clayman(2) + Burstinatrix(1);
	#         7 = Clayman(2) + Bubbleman(3); 8 = Avian(0) + Bubbleman(3).
	# =====================================================================================
	print("-- Jaden: all four fusion gates --")
	var recipes = [
		[4, 0, 1, "Elemental HERO Avian", "Elemental HERO Burstinatrix"],
		[5, 2, 1, "Elemental HERO Clayman", "Elemental HERO Burstinatrix"],
		[6, 2, 3, "Elemental HERO Clayman", "Elemental HERO Bubbleman"],
		[7, 0, 3, "Elemental HERO Avian", "Elemental HERO Bubbleman"],
	]
	for r in recipes:
		var fusion = _skill(jaden, r[0])
		_clear_all(jaden)
		_check(fusion.extra_usable(jaden) == false,
			"[control] %s is dark with NO ingredients" % fusion.ability_name)
		_cast(jaden, _skill(jaden, r[1]), [jaden], m)
		_check(fusion.extra_usable(jaden) == false,
			"[control] %s is still dark with only %s" % [fusion.ability_name, r[3]])
		_cast(jaden, _skill(jaden, r[2]), [jaden], m)
		_check(fusion.extra_usable(jaden) == true,
			"POSITIVE: %s LIGHTS UP on %s + %s" % [fusion.ability_name, r[3], r[4]])
		_cast(jaden, fusion, [jaden], m)
		_check(jaden.effects.has_effect(r[3], EffectType.Type.TICKING_TRIGGER, jaden) == null
				and jaden.effects.has_effect(r[4], EffectType.Type.TICKING_TRIGGER, jaden) == null,
			"...and using it CONSUMES both ingredients")
		_check(fusion.extra_usable(jaden) == false,
			"...so it cannot be used a second time")
	_clear_all(jaden)

	# =====================================================================================
	# JADEN 3 - Burstinatrix's per-turn Affliction is 5, in the manual instance AND the tick.
	# =====================================================================================
	print("-- Jaden: Burstinatrix deals 5 (was 10) --")
	var burst = _skill(jaden, 1)
	var before = foe.health.hp
	_cast(jaden, burst, [jaden], m)
	_check(foe.health.hp == before - 5,
		"POSITIVE: Burstinatrix's first instance deals 5 Affliction (dealt %d)" % (before - foe.health.hp))
	var tick_eff = jaden.effects.has_effect("Elemental HERO Burstinatrix", EffectType.Type.TICKING_TRIGGER, jaden)
	before = foe.health.hp
	m.execute_ticking_effect(tick_eff)
	_check(foe.health.hp == before - 5,
		"POSITIVE: ...and so does the tick (dealt %d)" % (before - foe.health.hp))
	_clear_all(jaden)

	# =====================================================================================
	# SOUL 1 - Scythe Transformation plants the wield handle + the growth trigger.
	# =====================================================================================
	print("-- Soul: Scythe Transformation --")
	_cast(soul, _skill(soul, 0), [ally], m)
	var wield = ally.effects.has_effect("Scythe Transformation", EffectType.Type.MARK, soul)
	var boost = ally.effects.has_effect("Scythe Transformation", EffectType.Type.DAMAGE_MOD, soul)
	_check(wield != null, "POSITIVE: the wield MARK landed on the ally")
	_check(boost != null and boost.mag == 5, "POSITIVE: the damage bonus starts at 5 (is %s)" % str(boost.mag if boost else "absent"))
	_check(ally.effects.has_effect("Scythe Transformation", EffectType.Type.DAMAGE_RECEIVE_TRIGGER, soul) != null,
		"POSITIVE: the +5-per-instance growth trigger landed on the wielder")

	# =====================================================================================
	# SOUL 2 - Nightmare Wavelength: 20 to the enemy, 10 to the WIELDER, 0 to Soul,
	#          and the growth trigger fires off that very hit.
	# =====================================================================================
	print("-- Soul: Nightmare Wavelength, wielded --")
	var foe_hp = foe.health.hp
	var soul_hp = soul.health.hp
	var ally_hp = ally.health.hp
	_cast(soul, _skill(soul, 1), [foe], m)
	_check(foe_hp - foe.health.hp == 20,
		"POSITIVE: the enemy takes 20 Affliction (took %d)" % (foe_hp - foe.health.hp))
	_check(ally_hp - ally.health.hp == 10,
		"POSITIVE: the WIELDER takes the 10 recoil (took %d)" % (ally_hp - ally.health.hp))
	_check(soul.health.hp == soul_hp,
		"POSITIVE: Soul takes 0 while wielded - 'instead of', not split (took %d)" % (soul_hp - soul.health.hp))
	_check(boost.mag == 10,
		"POSITIVE: that hit grew Scythe Transformation's bonus 5 -> 10 (is %d)" % boost.mag)

	# Per INSTANCE, not per turn: a second Wavelength in the same window grows it again.
	foe_hp = foe.health.hp
	_cast(soul, _skill(soul, 1), [foe], m)
	_check(boost.mag == 15, "POSITIVE: a SECOND hit grows it again, 10 -> 15 (is %d) - per instance, not per turn" % boost.mag)
	# Control: an ENEMY hitting the wielder must not feed the bonus.
	foe.used_ability = foe.moveset.base_abilities[0]
	foe.targeter.targets = [ally]
	Character.resolve_damage(QueryContext.from_game_state(foe, m), ally, 10, DamageType.Type.NORMAL)
	_check(boost.mag == 15, "[control] damage from an ENEMY does not grow the bonus (still %d)" % boost.mag)

	# =====================================================================================
	# SOUL 3 - Nightmare Sonata: +10 (not +20) to the ENEMY hit, and the 3-turn tick.
	# =====================================================================================
	print("-- Soul: Nightmare Sonata --")
	var enemies = p2.team.characters
	var pre_hp = {}
	for e in enemies:
		pre_hp[e] = e.health.hp
	ally_hp = ally.health.hp
	_cast(soul, _skill(soul, 2), enemies, m)
	var all_hit = true
	for e in enemies:
		if pre_hp[e] - e.health.hp != 10:
			all_hit = false
	_check(all_hit, "POSITIVE: Sonata's tick lands on the CAST turn - every target took 10 Affliction")
	_check(ally_hp - ally.health.hp == 10,
		"POSITIVE: ...and the wielding ally took 10 too (took %d)" % (ally_hp - ally.health.hp))
	var dot = enemies[0].effects.has_effect("Nightmare Sonata", EffectType.Type.DAMAGE, soul)
	_check(dot != null and dot.duration == 5,
		"POSITIVE: the per-target DoT runs duration 5 (2N-1 for a 3-turn window; is %s)" % str(dot.duration if dot else "absent"))
	var wielder_tick = soul.effects.has_effect("Nightmare Sonata", EffectType.Type.TICKING_TRIGGER, soul)
	_check(wielder_tick != null and wielder_tick.duration == 5,
		"POSITIVE: the wielder tick is a TICKING_TRIGGER on Soul at duration 5 (so it re-resolves who wields him)")

	# The wielder tick follows the handle: move the wield to another ally and the damage follows.
	if wielder_tick != null:
		ally_hp = ally.health.hp
		var soul_hp2 = soul.health.hp
		ally.effects.erase_effect(wield)
		m.execute_ticking_effect(wielder_tick)
		_check(ally.health.hp == ally_hp and soul_hp2 - soul.health.hp == 0,
			"[control] with nobody wielding Soul, the wielder tick damages NOBODY")

	# The per-target DoT actually ticks for 10.
	if dot != null:
		var d_hp = enemies[0].health.hp
		m.execute_ticking_effect(dot)
		_check(d_hp - enemies[0].health.hp == 10,
			"POSITIVE: the per-target DoT ticks for 10 Affliction (dealt %d)" % (d_hp - enemies[0].health.hp))

	# Null-safety: GDScript runtime errors LOG AND CONTINUE, so a dead branch here would show up
	# as stderr spam and a silently dead passive, never as a failed assertion. Strip the bonus the
	# growth trigger writes into and hit the wielder anyway.
	_cast(soul, _skill(soul, 0), [ally], m)
	var live_boost = ally.effects.has_effect("Scythe Transformation", EffectType.Type.DAMAGE_MOD, soul)
	if live_boost != null:
		ally.effects.erase_effect(live_boost)
	_cast(soul, _skill(soul, 1), [foe], m)
	_check(ally.effects.has_effect("Scythe Transformation", EffectType.Type.DAMAGE_MOD, soul) == null,
		"[null-safety] the growth trigger survives its target bonus being cleansed away")

	# Sonata's boost is now +10 on the ENEMY hit (it used to be +20 on the self/ally half only).
	# Measured as a DELTA against an unboosted cast on the same enemy in the same state: an absolute
	# number would be at the mercy of whatever standing modifiers the board has accumulated.
	print("-- Soul: Sonata's boost moved onto the enemy hit, 20 -> 10 --")
	var foe2 = p2.team.characters[2]
	_clear_all(soul)
	_clear_all(ally)          # nobody wields Soul from here on - the recoil must land on him
	var h = foe2.health.hp
	soul_hp = soul.health.hp
	_cast(soul, _skill(soul, 1), [foe2], m)
	var unboosted = h - foe2.health.hp
	_check(soul_hp - soul.health.hp == 10,
		"POSITIVE: unwielded, Soul himself eats the flat 10 recoil (took %d)" % (soul_hp - soul.health.hp))
	var sonata_mark = Effect.mark(5, "Nightmare Wavelength will deal 10 more damage.")
	sonata_mark.set_source(_skill(soul, 2))
	Character.add_allied_effect(QueryContext.from_game_state(soul, m), soul, soul, sonata_mark)
	h = foe2.health.hp
	soul_hp = soul.health.hp
	_cast(soul, _skill(soul, 1), [foe2], m)
	var boosted = h - foe2.health.hp
	_check(boosted - unboosted == 10,
		"POSITIVE: Sonata adds exactly 10 to the ENEMY hit (%d -> %d)" % [unboosted, boosted])
	_check(soul_hp - soul.health.hp == 10,
		"POSITIVE: ...and NOT to the recoil - Sonata must not be a self-nerf (took %d)" % (soul_hp - soul.health.hp))

	print("=== %d FAILURES ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
