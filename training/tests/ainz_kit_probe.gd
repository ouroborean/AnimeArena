extends Node

# Ainz Ooal Gown — full kit + engine probe.
#   godot --headless --path <repo> res://training/tests/ainz_kit_probe.tscn

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

func _harmful_src(foe):
	for a in foe.moveset.base_abilities:
		if a.classes.get("Harmful", false):
			return a
	return foe.moveset.base_abilities[0]

func _count(c, t):
	return c.effects.get_effects_by_type(t).size()

func _cast(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0]
	caster.used_ability = ab
	ab.execute(caster, m)

func _ready():
	print("=== ainz kit probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Ainz", ["ainz", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["killua", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var ainz = p1.team.characters[0]
	var ally = p1.team.characters[1]
	var foe = p2.team.characters[0]
	var foe2 = p2.team.characters[1]
	var TT = EffectType.Type
	var qc = QueryContext.from_game_state(foe, m)

	_check(ainz.moveset.base_abilities.size() == 6, "[setup] Ainz has 6 abilities")
	var goal_mark = ainz.has_effect("The Goal of all Life is Death", TT.MARK, ainz)
	_check(goal_mark != null and int(goal_mark.mag) == 0, "[passive] trigger counter installed at 0")

	var astral = ainz.moveset.base_abilities[1]
	var wall = ainz.moveset.base_abilities[3]
	var base_astral_random = astral.cost().get(4, 0)   # 0

	# === 1. NEGATION (all effects) + once-per-turn stack cap + 3-turn cost window + distinct render ids ===
	# Three harmful non-damage effects in ONE turn: all negated, but only ONE stack (counter + cost) gained.
	for k in range(3):
		var e = Effect.stun_effect(2)
		e.set_source(_harmful_src(foe))
		Character.add_hostile_effect(qc, foe, ainz, e)
	_check(_count(ainz, TT.STUN) == 0, "[negate] all 3 incoming Stuns negated (none landed)")
	_check(int(ainz.has_effect("The Goal of all Life is Death", TT.MARK, ainz).stack_count()) == 1, "[cap] 3 negations in one turn -> counter +1 only")
	_check(_count(ainz, TT.COST_MOD) == 1, "[cap] ...and only ONE cost-mod installed")
	_check(int(ainz.effects.get_effects_by_type(TT.COST_MOD)[0].duration) == 6, "[cost] cost-mod lasts 3 turns (dur 6, fixed — not the negated effect's duration)")

	# A NEW turn allows a second stack, with a DISTINCT (current-time) render id.
	m.current_turn_number += 1
	OS.delay_msec(3)
	var eiso = Effect.isolate(2)
	eiso.set_source(_harmful_src(foe))
	Character.add_hostile_effect(qc, foe, ainz, eiso)
	_check(_count(ainz, TT.ISOLATE) == 0, "[negate] a different type (Isolate) is negated too")
	_check(int(ainz.has_effect("The Goal of all Life is Death", TT.MARK, ainz).stack_count()) == 2, "[cap] a NEW turn allows a second stack (counter 2)")
	var cms = ainz.effects.get_effects_by_type(TT.COST_MOD)
	_check(cms.size() == 2, "[cost] a second cost-mod stacked")
	_check(cms[0].unique_render_id != cms[1].unique_render_id and cms[0].unique_render_id != 0, "[render] the two cost-mod stacks have DISTINCT render ids")
	_check(astral.cost().get(4, 0) == base_astral_random + 2, "[cost] Astral Smite now costs +2 Random (2 stacks)")

	# === 2. DAMAGE is NOT negated (and never stacks — even on a fresh turn where a stack WOULD be allowed) ===
	m.current_turn_number += 1
	var before_dot = int(ainz.has_effect("The Goal of all Life is Death", TT.MARK, ainz).stack_count())
	var dot = Effect.damage_effect(5, DamageType.Type.NORMAL, 4)
	dot.set_source(_harmful_src(foe))
	Character.add_hostile_effect(qc, foe, ainz, dot)
	_check(_count(ainz, TT.DAMAGE) >= 1, "[negate] a DAMAGE effect (DoT) still lands (not negated)")
	_check(int(ainz.has_effect("The Goal of all Life is Death", TT.MARK, ainz).stack_count()) == before_dot, "[negate] ...and does NOT stack (damage-type exclusion, independent of the per-turn cap)")

	# === 3. cost_locked: Wall of Protection's cost is untouched by the +Random cost-mod ===
	_check(wall.cost().get(4, 0) == 1, "[cost_locked] Wall of Protection stays at 1 Random (cost cannot be increased)")

	# === 4. Astral Smite scaling: 20 + 5*triggers(2) + 5*extra(2) = 40 ===
	var f0 = foe.health.hp
	_cast(m, ainz, 1, [foe])
	_check(f0 - foe.health.hp == 40, "[Astral Smite] 20 + 5*trigger(2) + 5*extra(2) = 40 (dealt %d)" % (f0 - foe.health.hp))

	# === 5. Hold of Ribs: isolate+shatter, duration scales with extra energy, swaps slot 0 -> Fallen Down ===
	_cast(m, ainz, 0, [foe2])
	_check(_count(foe2, TT.ISOLATE) >= 1 and _count(foe2, TT.DEF_NEGATE) >= 1, "[Hold of Ribs] target Isolated + Shattered")
	var iso = foe2.has_effect("Hold of Ribs", TT.ISOLATE, ainz)
	_check(iso != null and int(iso.duration) == (1 + 2) * 2, "[Hold of Ribs] duration scaled by extra energy (dur %d == 6)" % (int(iso.duration) if iso else -1))
	var slot0 = ainz.moveset.get_active_abilities(ainz)[0]
	_check(slot0.ability_name == "Fallen Down", "[Hold of Ribs] slot 0 is now Fallen Down (%s)" % slot0.ability_name)

	# === 6. Fallen Down (index 5): 35 + 10 (full HP) + 5*triggers(2) = 55 on a full-HP foe ===
	var foe3 = p2.team.characters[2]
	var g0 = foe3.health.hp
	_cast(m, ainz, 5, [foe3])
	_check(g0 - foe3.health.hp == 55, "[Fallen Down] 35 + 10(full HP) + 5*trigger(2) = 55 (dealt %d)" % (g0 - foe3.health.hp))

	# === 7. Gravity Maelstrom: 15 Piercing to all + damage-down; Hold-of-Ribs'd foe also Stunned ===
	var b0 = foe.health.hp
	_cast(m, ainz, 2, [foe, foe2, foe3])
	_check(b0 - foe.health.hp == 15, "[Gravity Maelstrom] 15 Piercing to a plain enemy (dealt %d)" % (b0 - foe.health.hp))
	_check(_count(foe, TT.DAMAGE_MOD) >= 1, "[Gravity Maelstrom] applies a damage-down")
	_check(_count(foe2, TT.STUN) >= 1, "[Gravity Maelstrom] a Hold-of-Ribs'd enemy is also Stunned")

	# === 8. Wall of Protection: self -> Invuln; ally -> 50% DR ===
	_cast(m, ainz, 3, [ainz])
	_check(_count(ainz, TT.INVULN) >= 1, "[Wall of Protection] Ainz becomes Invulnerable")
	_cast(m, ainz, 3, [ally])
	_check(_count(ally, TT.PERCENT_DR) >= 1, "[Wall of Protection] an ally gets 50% Damage Reduction")

	# === 10. Madoka fix: a HELPFUL-classed enemy effect is negated too (any enemy non-damage effect is "negative") ===
	for e in ainz.effects.get_effects_by_type(TT.INVULN): ainz.effects.erase_effect(e)   # Wall of Protection left Ainz invuln
	m.current_turn_number += 1   # fresh turn so the once-per-turn cap allows a stack
	var before_k = int(ainz.has_effect("The Goal of all Life is Death", TT.MARK, ainz).stack_count())
	var karmic = Ability.from_database("madoka3")   # Karmic Destiny — Helpful class, plants an ACTION_USE_TRIGGER
	_check(karmic.classes.get("Harmful", false) == false and karmic.classes.get("Helpful", false), "[Madoka] Karmic Destiny is Helpful-classed (not Harmful)")
	var kt = Effect.trigger_effect(Trigger.always(func(_c): pass), TT.ACTION_USE_TRIGGER, 6, "karmic")
	kt.set_source(karmic)
	Character.add_hostile_effect(qc, foe, ainz, kt)
	_check(_count(ainz, TT.ACTION_USE_TRIGGER) == 0, "[Madoka] a Helpful-classed enemy trigger is negated (so no Nullify-on-act)")
	_check(int(ainz.has_effect("The Goal of all Life is Death", TT.MARK, ainz).stack_count()) == before_k + 1, "[Madoka] ...and it counts as a passive trigger (stacking counter)")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
