extends Node

# Patch 2026-08-02 — consumer-side probe for the Yugi / Esdeath / Maka / Noelle / Tsubaki /
# Thompson Sisters / Katara cluster. The engine primitives (Ability.is_sealed_out, the
# check_cancels coupling) are covered by skill_seal_probe; THIS probe covers the ability
# scripts that ride them, plus the four presence-handle rewires in the same cluster.
#
# EVERY ONE of these failures is silent — a stale typed lookup or a dropped effect compiles,
# loads and renders, and shows up only as a button that is greyed forever or a debuff that
# quietly never lands. So each block asserts the POSITIVE case first: a negative-only
# assertion ("the exempt skill is still usable") passes against a change that does nothing.
#
#   godot --headless --path <repo> res://training/tests/patch0802_cluster_probe.tscn

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

# usable() gates on affordability first. An empty pool makes every "unusable" assertion below
# vacuously true and the probe would pass against a seal that seals nothing.
func _fill_energy(p):
	for colour in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		p.team.energy.pool[colour] = 20

func _battle(p1_names, p2_names) -> Array:
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", p1_names)
	var p2 = _build_player("BotEnemy", p2_names)
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	_fill_energy(p1)
	_fill_energy(p2)
	for c in p1.team.characters + p2.team.characters:
		c.refresh()
	return [m, p1, p2]

func _ctx(m, c):
	return QueryContext.from_game_state(c, m)

# usable() drives the local skill card, authoritative_usable() the `usable` flag in the wire
# snapshot. A change that only moves one produces a button that looks live and is rejected.
func _both(ab, c) -> Array:
	return [ab.usable(c), ab.authoritative_usable(c)]

# Re-runs the ability's own target() and reads back the `targeted` flags — the only honest way
# to ask "what can this skill legally point at right now", since target() has no return value.
func _targets_of(m, c, ab) -> Array:
	for x in m.all_characters():
		x.set_untargeted()
	ab.target(c, m)
	var out := []
	for x in m.all_characters():
		if x.targeted:
			out.append(x)
	for x in m.all_characters():
		x.set_untargeted()
	return out

func _names(chars) -> Array:
	var out := []
	for c in chars:
		out.append(c.character_name)
	return out

func _cast(m, c, ab, targets):
	c.targeter.targets = targets
	c.targeter.main_target = targets[0] if targets.size() > 0 else null
	c.used_ability = ab
	ab.execute(c, m)
	# usable() rejects any character whose used_ability is set (one action per turn). Leaving it
	# behind would make EVERY post-cast "still usable" assertion below false for the caster, for
	# a reason that has nothing to do with the seal. A real turn clears it in refresh().
	c.used_ability = null

func _slot(c, idx, expected_name):
	var ab = c.moveset.base_abilities[idx]
	_check(ab.ability_name == expected_name,
		"%s slot %d is %s (found %s)" % [c.character_name, idx, expected_name, ab.ability_name])
	return ab

func _clear_seals_everywhere(m):
	for c in m.all_characters():
		for eff in c.effects.get_effects_by_type(EffectType.Type.MARK):
			if eff.skill_seal:
				c.effects.erase_effect(eff)
		# Mahapadma / Swords are non-ignorable STUNs now (not seals) — clear those between sections too.
		for eff in c.effects.get_effects_by_type(EffectType.Type.STUN):
			c.effects.erase_effect(eff)


func _ready():
	print("=== patch 2026-08-02 cluster probe ===")
	_esdeath_and_yugi_and_maka()
	_noelle_and_tsubaki()
	_thompson_and_katara()
	print("=== %s ===" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	get_tree().quit(0 if fails == 0 else 1)


# =========================================================================================
# BATTLE 1 — Esdeath's Mahapadma, Yugi's Swords of Revealing Light, Maka's Witch Hunter.
# =========================================================================================
func _esdeath_and_yugi_and_maka():
	var b = _battle(["esdeath", "yugi", "maka"], ["gray", "naruto", "gon"])
	var m = b[0]
	var esdeath = b[1].team.characters[0]
	var yugi = b[1].team.characters[1]
	var maka = b[1].team.characters[2]
	var foe = b[2].team.characters[0]

	# ---------------------------------------------------------------------------------
	# ESDEATH — Mahapadma is a full skill seal now, not a stun.
	# ---------------------------------------------------------------------------------
	print("-- Esdeath: Mahapadma --")
	var mahapadma = _slot(esdeath, 1, "Mahapadma")
	var foe_skill = foe.moveset.base_abilities[0]
	var esdeath_skill = _slot(esdeath, 0, "Empire's Strongest")
	# Unstunnable buys nothing under a seal: Dark Magician Girl carries that class.
	var unstunnable = _slot(yugi, 1, "Dark Magician Girl")
	_check(_both(foe_skill, foe) == [true, true], "[baseline] the enemy's skill is usable before Mahapadma")
	_check(_both(unstunnable, yugi) == [true, true], "[baseline] the Unstunnable skill is usable before Mahapadma")

	var mahapadma_targets = _targets_of(m, esdeath, mahapadma)
	_check(not esdeath in mahapadma_targets, "Mahapadma is selfless — Esdeath is not among its own targets")
	_cast(m, esdeath, mahapadma, mahapadma_targets)

	_check(_both(foe_skill, foe) == [false, false],
		"POSITIVE: a sealed ENEMY's skill reports usable == false from both call sites")
	_check(_both(unstunnable, yugi) == [false, false],
		"POSITIVE: Mahapadma seals Esdeath's own ALLY too, and Unstunnable does not exempt him (scope kept, Q8)")
	_check(_both(esdeath_skill, esdeath) == [true, true], "Esdeath herself is not sealed")
	_check(foe.effects.has_effect("Mahapadma", EffectType.Type.STUN, esdeath) != null,
		"POSITIVE: the effect applied is a STUN named Mahapadma")
	_check(foe.effects.get_effects_by_type(EffectType.Type.MARK).filter(func(e): return e.skill_seal).size() == 0,
		"POSITIVE: no skill_seal MARK was applied (Mahapadma is a non-ignorable stun now, not a seal)")
	var landed = foe.effects.has_effect("Mahapadma", EffectType.Type.STUN, esdeath)
	_check(landed != null and landed.duration == 4, "Mahapadma's duration is 4 (== 2 turns)")
	_check(landed != null and not landed.ignorable, "Mahapadma's stun is non-ignorable (cannot be shrugged)")
	_check(landed != null and landed.remove_on_death, "the stun is removed on death (owner ruling, preserved from the seal)")

	# The self-penalty. The old code probed STUN here; probing the wrong type makes the guard
	# always miss and the recoil re-applies once per expiring target.
	print("-- Esdeath: the self-penalty fires exactly once --")
	mahapadma.timeout_trigger(_ctx(m, esdeath))
	_check(esdeath.effects.has_effect("Mahapadma", EffectType.Type.STUN, esdeath) != null,
		"POSITIVE: Esdeath takes the recoil, and it is the same prevention she dealt (Q9)")
	_check(_both(esdeath_skill, esdeath) == [false, false],
		"POSITIVE: ...so Esdeath's own skills are now unusable too")
	mahapadma.timeout_trigger(_ctx(m, esdeath))
	mahapadma.timeout_trigger(_ctx(m, esdeath))
	_check(esdeath.effects.get_all_effects_by_name("Mahapadma", esdeath).size() == 1,
		"POSITIVE: three expiries later there is still exactly ONE recoil seal (no double-fire)")
	_clear_seals_everywhere(m)

	# ---------------------------------------------------------------------------------
	# YUGI — Swords of Revealing Light: class-filtered seal + name exclusion.
	# ---------------------------------------------------------------------------------
	print("-- Yugi: Swords of Revealing Light --")
	var swords = _slot(yugi, 2, "Swords of Revealing Light")
	var kuriboh = _slot(yugi, 0, "Kuriboh")            # Harmful, and Yugi's own — sealed
	var dark_magician = _slot(yugi, 4, "Dark Magician")
	var girl = _slot(yugi, 1, "Dark Magician Girl")
	var foe_harmful = null
	var foe_soft = null
	for ab in foe.moveset.base_abilities:
		if not ab.usable(foe):
			continue
		if ab.classes.get("Harmful", false):
			if foe_harmful == null:
				foe_harmful = ab
		elif foe_soft == null:
			foe_soft = ab
	_check(foe_harmful != null and foe_soft != null,
		"found a usable Harmful and a usable non-Harmful skill on %s" % foe.character_name)
	_check(_both(kuriboh, yugi) == [true, true], "[baseline] Yugi's own Harmful skill is usable before Swords")

	var swords_targets = _targets_of(m, yugi, swords)
	_check(yugi in swords_targets, "Swords targets both teams INCLUDING Yugi himself (scope kept, Q8)")
	_cast(m, yugi, swords, swords_targets)

	_check(_both(foe_harmful, foe) == [false, false],
		"POSITIVE: the enemy's Harmful skill reports usable == false from both call sites")
	_check(_both(kuriboh, yugi) == [false, false],
		"POSITIVE: Yugi seals his own Harmful skills too")
	_check(_both(foe_soft, foe) == [true, true], "a non-Harmful skill is untouched by the class filter")
	_check(_both(girl, yugi) == [true, true],
		"Dark Magician Girl is name-EXCLUDED and stays usable (this is what lets Yugi end his own Swords)")
	_check(_both(dark_magician, yugi) == [true, true], "Dark Magician is name-excluded and stays usable")

	var swap = yugi.effects.has_effect("Swords of Revealing Light", EffectType.Type.ABILITY_SWAP, yugi)
	_check(swap != null and swap.duration == 7,
		"the paired ability swap is duration 7 (3 turns, 2N+1) so it no longer reverts before the seal (Q6)")

	# The four STUN->MARK lookups. yugi2 must find Swords by MARK or its whole
	# "end Swords + swap" branch dies with no error.
	print("-- Yugi: Dark Magician Girl can still end his own Swords --")
	_cast(m, yugi, girl, [foe])
	var still_sealed := 0
	for c in m.all_characters():
		if c.effects.has_effect("Swords of Revealing Light", EffectType.Type.STUN, yugi) != null:
			still_sealed += 1
	_check(still_sealed == 0,
		"POSITIVE: Dark Magician Girl cleared Swords off every character (%d still sealed)" % still_sealed)
	_check(_both(kuriboh, yugi) == [true, true], "...and Yugi's Harmful skills are usable again")
	_clear_seals_everywhere(m)

	# ---------------------------------------------------------------------------------
	# MAKA — Witch Hunter loses its break trigger; Figure-6 Hunter re-keys onto the DAMAGE.
	# ---------------------------------------------------------------------------------
	print("-- Maka: Witch Hunter / Figure-6 Hunter --")
	var witch = _slot(maka, 2, "Witch Hunter")
	var figure6 = _slot(maka, 4, "Figure-6 Hunter")
	# Control FIRST: with no Witch Hunter out, Figure-6 Hunter has nothing to point at.
	_check(_targets_of(m, maka, figure6).size() == 0,
		"[control] Figure-6 Hunter has zero targets before Witch Hunter lands")

	var victim = b[2].team.characters[1]
	_cast(m, maka, witch, [victim])
	var f6 = _targets_of(m, maka, figure6)
	_check(f6.size() == 1 and f6[0] == victim,
		"POSITIVE: Figure-6 Hunter finds its victim through the DAMAGE effect (%s)" % str(_names(f6)))
	_check(victim.effects.has_effect("Witch Hunter", EffectType.Type.HARMFUL_USE_TRIGGER, maka) == null,
		"POSITIVE: the HARMFUL_USE_TRIGGER is gone — nothing else may key off it")

	var victim_harmful = null
	for ab in victim.moveset.base_abilities:
		if ab.classes.get("Harmful", false):
			victim_harmful = ab
			break
	_check(victim_harmful != null, "found a Harmful skill on %s to break Witch Hunter with" % victim.character_name)
	victim.targeter.targets = [maka]
	victim.targeter.main_target = maka
	victim.check_ability_use_triggers(m, victim_harmful)
	_check(victim.effects.has_effect("Witch Hunter", EffectType.Type.DAMAGE, maka) != null,
		"POSITIVE: the victim used a new Harmful skill and Witch Hunter SURVIVED it")
	_check(_targets_of(m, maka, figure6).size() == 1,
		"POSITIVE: ...and Figure-6 Hunter still has its target afterwards")


# =========================================================================================
# BATTLE 2 — Noelle's Cradle under Valkyrie Dress, Tsubaki's Soul Resonance.
# =========================================================================================
func _noelle_and_tsubaki():
	var b = _battle(["noelle", "tsubaki", "blackstar"], ["gray", "naruto", "gon"])
	var m = b[0]
	var noelle = b[1].team.characters[0]
	var tsubaki = b[1].team.characters[1]
	var blackstar = b[1].team.characters[2]

	print("-- Noelle: Sea Dragon's Cradle under Valkyrie Dress --")
	var cradle = _slot(noelle, 1, "Sea Dragon's Cradle")
	var dress = _slot(noelle, 2, "Saint Valkyrie Dress")
	var mark_victim = b[2].team.characters[0]
	var victim_skill = mark_victim.moveset.base_abilities[0]

	# Control FIRST, with no Dress: the Cradle must still be consumed by the target's skill,
	# or the "survives" assertion below proves nothing.
	_cast(m, noelle, cradle, _targets_of(m, noelle, cradle))
	_check(mark_victim.effects.has_effect("Sea Dragon's Cradle", EffectType.Type.ACTION_USE_TRIGGER, noelle) != null,
		"the Cradle's ACTION_USE_TRIGGER handle is present (noelle1:20 / noelle5:20 read exactly this)")
	mark_victim.targeter.targets = [noelle]
	mark_victim.targeter.main_target = noelle
	mark_victim.check_ability_use_triggers(m, victim_skill)
	_check(mark_victim.effects.has_effect("Sea Dragon's Cradle", EffectType.Type.COST_MOD, noelle) == null,
		"[control] without Valkyrie Dress the target's skill still removes the Cradle")

	_cast(m, noelle, dress, [noelle])
	_check(noelle.marked_by("Saint Valkyrie Dress", noelle) != null, "Valkyrie Dress is up")
	_cast(m, noelle, cradle, _targets_of(m, noelle, cradle))
	_check(mark_victim.effects.has_effect("Sea Dragon's Cradle", EffectType.Type.COST_MOD, noelle) != null,
		"the Cradle re-applied under the Dress")
	mark_victim.check_ability_use_triggers(m, victim_skill)
	_check(mark_victim.effects.has_effect("Sea Dragon's Cradle", EffectType.Type.COST_MOD, noelle) != null,
		"POSITIVE: under Valkyrie Dress the target's skill does NOT remove the Cradle")
	_check(mark_victim.effects.has_effect("Sea Dragon's Cradle", EffectType.Type.ACTION_USE_TRIGGER, noelle) != null,
		"POSITIVE: ...and the TRIGGER itself survives, so noelle1/noelle5 can still find the Cradle")
	mark_victim.check_ability_use_triggers(m, victim_skill, true)
	_check(mark_victim.effects.has_effect("Sea Dragon's Cradle", EffectType.Type.COST_MOD, noelle) != null,
		"POSITIVE: a SECOND skill does not remove it either (the guard is on the body, not one-shot)")

	print("-- Tsubaki: Soul Resonance no longer waits on a skill use --")
	var kusarigama = _slot(tsubaki, 0, "Tsubaki Mode: Kusarigama")
	var resonance = _slot(tsubaki, 2, "Tsubaki Soul Resonance")
	var uncanny = _slot(tsubaki, 5, "Tsubaki Mode: Uncanny Sword")

	# Control FIRST: a target who is NOT wielding Tsubaki gets no copy — the wield gate stays.
	_cast(m, tsubaki, resonance, [noelle])
	_check(noelle.effects.get_effects_by_type(EffectType.Type.SKILL_COPY).size() == 0,
		"[control] a non-wielder gets the Shield but no skill replacement (the wield gate is intact)")

	_cast(m, tsubaki, kusarigama, [blackstar])
	_check(blackstar.marked_by("Tsubaki Mode: Kusarigama") != null, "Black Star is wielding Tsubaki")
	_cast(m, tsubaki, resonance, [blackstar])
	var copy = null
	for eff in blackstar.effects.get_effects_by_type(EffectType.Type.SKILL_COPY):
		if eff.ability_targets != null and eff.ability_targets.ability_name == uncanny.ability_name:
			copy = eff
	_check(copy != null,
		"POSITIVE: the copy lands at CAST time — Black Star never used a skill")
	_check(copy != null and copy.mag == 0,
		"POSITIVE: it occupies slot 0, the target's FIRST skill (Bestow's model)")
	_check(copy != null and copy.duration == 3, "duration 3 in the slot (covers the ally's next turn — Soul Resonance +1 extension)")
	_check(blackstar.moveset.get_active_abilities(blackstar)[0].ability_name == uncanny.ability_name,
		"POSITIVE: Black Star's first active skill really is Tsubaki Mode: Uncanny Sword")
	_check(blackstar.effects.has_effect("Tsubaki Soul Resonance", EffectType.Type.ACTION_USE_TRIGGER, tsubaki) == null,
		"the old ACTION_USE_TRIGGER is gone — nothing is left waiting on a skill use")


# =========================================================================================
# BATTLE 3 — the Thompson Sisters' mutual exclusion, and Katara's ally-targeted reflect.
# =========================================================================================
func _thompson_and_katara():
	var b = _battle(["lizandpatty", "kid", "kitara"], ["gray", "naruto", "gon"])
	var m = b[0]
	var lp = b[1].team.characters[0]
	var kid = b[1].team.characters[1]
	var kitara = b[1].team.characters[2]

	# ---------------------------------------------------------------------------------
	# KATARA first — the Thompson block below kills Kid to test the grey-out.
	# ---------------------------------------------------------------------------------
	print("-- Katara: Ice Deflection on any ally --")
	var deflect = _slot(kitara, 1, "Ice Deflection")
	var reachable = _targets_of(m, kitara, deflect)
	_check(kid in reachable and lp in reachable,
		"POSITIVE: Ice Deflection can reach allies now (%s)" % str(_names(reachable)))
	_check(kitara in reachable, "[control] ...and Katara herself while she is not isolated")
	_cast(m, kitara, deflect, [kid])
	_check(kid.effects.has_effect("Ice Deflection", EffectType.Type.REFLECT_RECEIVE, kitara) != null,
		"POSITIVE: the REFLECT_RECEIVE sits on the ALLY (reflect_check reads it off the attacker's targets)")

	var iso = Effect.isolate(4)
	iso.set_source(deflect)
	Character.add_allied_effect(_ctx(m, kitara), kitara, kitara, iso)
	_check(kitara.is_isolated(), "Katara is isolated")
	_check(not kitara in _targets_of(m, kitara, deflect),
		"POSITIVE: an isolated Katara can NO LONGER protect herself (Q19 answered 'no')")
	kitara.effects.erase_effect(iso)

	# ---------------------------------------------------------------------------------
	# THOMPSON SISTERS — Liz and Patty may not share a character, except Death the Kid.
	# ---------------------------------------------------------------------------------
	print("-- Thompson Sisters: Liz and Patty cannot share a wielder --")
	var liz = _slot(lp, 0, "Transform: Liz")
	var patty = _slot(lp, 1, "Transform: Patty")
	_check(kitara in _targets_of(m, lp, patty), "[baseline] Patty can reach Katara before Liz lands on her")

	_cast(m, lp, liz, [kitara])
	_check(kitara.effects.has_effect("Transform: Liz", EffectType.Type.HARMFUL_USE_TRIGGER, lp) != null,
		"Katara is wielding Liz (the HARMFUL_USE_TRIGGER handle, the same one lizandpatty3/5/6 read)")
	var after = _targets_of(m, lp, patty)
	_check(not kitara in after,
		"POSITIVE: Patty can no longer target the character already wielding Liz (%s)" % str(_names(after)))
	_check(lp in after, "...but an unencumbered ally is still reachable")
	_check(patty.extra_usable(lp), "Transform: Patty is still usable while a legal target remains")

	# The mirror. lizandpatty1 and lizandpatty2 carry separate copies of the rule, so proving one
	# direction proves nothing about the other.
	_check(lp in _targets_of(m, lp, liz), "[baseline] Liz can reach the Sisters themselves before Patty lands")
	_cast(m, lp, patty, [lp])
	_check(not lp in _targets_of(m, lp, liz),
		"POSITIVE: and symmetrically, Liz can no longer target the character already wielding Patty")

	_cast(m, lp, liz, [kid])
	_check(kid.effects.has_effect("Transform: Liz", EffectType.Type.HARMFUL_USE_TRIGGER, lp) != null
		and kid.effects.has_effect("Transform: Patty", EffectType.Type.HARMFUL_USE_TRIGGER, lp) != null,
		"POSITIVE: Death the Kid dual-wields — the double-apply branch is untouched")
	_check(kid in _targets_of(m, lp, patty),
		"POSITIVE: and Patty may still be aimed at Kid despite Liz already being on him (the exemption)")

	# Grey-out: leave no legal target at all. Every remaining ally holds Liz, and Kid — the one
	# exemption — is off the board.
	var liz_on_self = Effect.trigger_effect(Trigger.always(liz.harmful_use_trigger),
		EffectType.Type.HARMFUL_USE_TRIGGER, 9, "wield handle (probe)")
	liz_on_self.set_source(liz)
	Character.add_allied_effect(_ctx(m, lp), lp, lp, liz_on_self)
	kid.dead = true
	_check(_targets_of(m, lp, patty).size() == 0,
		"POSITIVE: with every living ally already wielding Liz, Patty has zero targets")
	_check(patty.extra_usable(lp) == false,
		"POSITIVE: ...and extra_usable agrees, so the button greys instead of failing after payment")
	kid.dead = false
	_check(patty.extra_usable(lp), "restoring Kid makes Patty usable again")
