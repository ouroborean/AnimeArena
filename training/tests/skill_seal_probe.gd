extends Node

# Skill-seal engine probe (patch 2026-08-02, phase 1).
#
# WHAT IS UNDER TEST, and why it needs a probe rather than a compile:
#   1. Ability.is_sealed_out() — the ONE function both usable() and authoritative_usable() now call.
#      It grew CLASS matching (Yugi's Swords of Revealing Light seals "Harmful") and a NAME
#      EXCLUSION list (Dark Magician / Dark Magician Girl stay usable under it) on top of the
#      shipped name-list seal (Itachi's Totsuka Blade) and the unfiltered seal (Esdeath's
#      Mahapadma). A seal that silently does nothing compiles, loads and renders perfectly.
#   2. The seal is NOT a stun: none of the stun escape hatches may exempt a skill from it.
#   3. Character.check_cancels() — a seal still breaks the holder's channels (owner ruling), even
#      though is_stunned() is blind to it, and a seal whose filter does not cover the channelled
#      skill must leave the channel alone.
#   4. check_effect_breaking's Jaden hook, narrowed from a "Elemental HERO" PREFIX to an explicit
#      list: Avian / Burstinatrix / Bubbleman / CLAYMAN no longer tear down on a Shield break, and
#      Mudballman still do.
#
# ASSERTION ORDER IS DELIBERATE: every block asserts the POSITIVE case first (a sealed skill
# reports usable == false). A negative-only probe ("the exempt skill is still usable") passes
# against a seal that does nothing at all, because under a no-op seal EVERYTHING is usable.
#
#   godot --headless --path <repo> res://training/tests/skill_seal_probe.tscn

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

# usable() gates on affordability first; an empty pool would make every assertion below vacuously
# "unusable" and the probe would pass against a no-op seal.
func _fill_energy(p):
	for colour in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		p.team.energy.pool[colour] = 20

func _ctx(m, c):
	return QueryContext.from_game_state(c, m)

# Both call sites must agree — usable() drives the local skill card, authoritative_usable() the
# `usable` flag in the wire snapshot. Editing one produces a button that looks live and is rejected.
func _both(ab, c) -> Array:
	return [ab.usable(c), ab.authoritative_usable(c)]

func _seal(m, caster, victim, class_list := [], name_list := [], exclusions := []):
	var seal = Effect.mark(6, "This character cannot use skills (test seal).")
	seal.skill_seal = true
	seal.class_targets = class_list
	seal.ability_targets = name_list
	seal.exclusion_targets = exclusions
	seal.name_override = "Test Seal"
	seal.set_source(caster.moveset.base_abilities[0])
	Character.add_hostile_effect(_ctx(m, caster), caster, victim, seal)
	return victim.effects.has_effect("Test Seal", EffectType.Type.MARK)

func _clear_seals(c):
	for eff in c.effects.get_effects_by_type(EffectType.Type.MARK):
		if eff.skill_seal:
			c.effects.erase_effect(eff)

func _stun(m, caster, victim, dur := 6):
	var stun = Effect.stun_effect(dur)
	stun.set_source(caster.moveset.base_abilities[0])
	Character.add_hostile_effect(_ctx(m, caster), caster, victim, stun)

func _clear_type(c, t):
	for eff in c.effects.get_effects_by_type(t):
		c.effects.erase_effect(eff)

# A subject needs two Harmful skills (one sealed, one name-exempted) and one non-Harmful skill,
# all three usable BEFORE any seal exists — otherwise "unusable under the seal" proves nothing.
func _pick_subject(chars):
	for c in chars:
		var harm := []
		var soft := []
		for ab in c.moveset.base_abilities:
			if not ab.usable(c):
				continue
			if ab.classes.get("Harmful", false):
				harm.append(ab)
			else:
				soft.append(ab)
		if harm.size() >= 2 and soft.size() >= 1:
			return {"char": c, "harm_a": harm[0], "harm_b": harm[1], "soft": soft[0]}
	return {}

# Plant a named marker sourced to `ability` on BOTH Jaden and an enemy. break_hero wipes every
# same-named effect off EVERY character, so this is what makes the hook's firing observable.
func _plant_hero_markers(m, jaden, foe, ability):
	var mine = Effect.mark(-1, "hero marker")
	mine.set_source(ability)
	Character.add_allied_effect(_ctx(m, jaden), jaden, jaden, mine)
	var theirs = Effect.mark(-1, "hero marker")
	theirs.set_source(ability)
	Character.add_hostile_effect(_ctx(m, jaden), jaden, foe, theirs)

func _markers_live(jaden, foe, ability_name) -> int:
	var n := 0
	if jaden.effects.has_effect(ability_name, EffectType.Type.MARK, jaden):
		n += 1
	if foe.effects.has_effect(ability_name, EffectType.Type.MARK, jaden):
		n += 1
	return n

func _shield_of(c, ability_name):
	return c.effects.has_effect(ability_name, EffectType.Type.SHIELD, c)


func _ready():
	print("=== skill seal probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["maka", "jaden", "itachi"])
	var p2 = _build_player("BotEnemy", ["gray", "naruto", "gon"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	_fill_energy(p1)
	_fill_energy(p2)
	for c in p1.team.characters + p2.team.characters:
		c.refresh()

	var picked = _pick_subject(p2.team.characters)
	_check(not picked.is_empty(), "found a subject with 2 usable Harmful skills + 1 usable non-Harmful skill")
	if picked.is_empty():
		print("=== 1 FAILURES ===")
		get_tree().quit(1)
		return
	var subject = picked["char"]
	var harm_a = picked["harm_a"]
	var harm_b = picked["harm_b"]
	var soft = picked["soft"]
	var caster = p1.team.characters[2]        # Itachi — the shipped seal author, used as the applier
	print("  subject: %s | sealed Harmful: %s | exempt Harmful: %s | non-Harmful: %s"
		% [subject.character_name, harm_a.ability_name, harm_b.ability_name, soft.ability_name])

	# =====================================================================================
	# BASELINE — nothing sealed. If these are not usable, everything after it is vacuous.
	# =====================================================================================
	for ab in [harm_a, harm_b, soft]:
		var r = _both(ab, subject)
		_check(r[0] and r[1], "[baseline] %s is usable from BOTH call sites before any seal" % ab.ability_name)

	# =====================================================================================
	# 1. CLASS-FILTERED SEAL + NAME EXCLUSION — Yugi's Swords of Revealing Light.
	# =====================================================================================
	print("-- class-filtered seal (Harmful) with a name exclusion --")
	_check(_seal(m, caster, subject, ["Harmful"], [], [harm_b.ability_name]) != null, "the class seal landed")
	var a = _both(harm_a, subject)
	_check(a[0] == false, "POSITIVE: the Harmful skill %s reports usable == false" % harm_a.ability_name)
	_check(a[1] == false, "POSITIVE: ...and authoritative_usable == false (the wire snapshot agrees)")
	var b = _both(harm_b, subject)
	_check(b[0] and b[1], "the NAME-EXCLUDED Harmful skill %s stays usable from both sites" % harm_b.ability_name)
	var s = _both(soft, subject)
	_check(s[0] and s[1], "the non-Harmful skill %s stays usable from both sites" % soft.ability_name)
	# Control: an unsealed teammate is untouched by a seal on someone else.
	var bystander = null
	for c in p2.team.characters:
		if c != subject:
			bystander = c
			break
	var by_ab = bystander.moveset.base_abilities[0]
	_check(by_ab.usable(bystander) == by_ab.authoritative_usable(bystander),
		"[control] an UNSEALED teammate's skill is unaffected (both sites agree: %s)" % str(by_ab.usable(bystander)))
	_clear_seals(subject)
	_check(_both(harm_a, subject) == [true, true], "removing the seal restores %s" % harm_a.ability_name)

	# =====================================================================================
	# 2. UNFILTERED SEAL — Esdeath's Mahapadma. Every list empty == seal everything.
	# =====================================================================================
	print("-- unfiltered seal (Mahapadma) --")
	_seal(m, caster, subject)
	for ab in [harm_a, harm_b, soft]:
		var r = _both(ab, subject)
		_check(r[0] == false and r[1] == false,
			"POSITIVE: %s is unusable from BOTH sites under an unfiltered seal" % ab.ability_name)
	_clear_seals(subject)

	# =====================================================================================
	# 3. NAME-LIST SEAL — Totsuka Blade's shipped shape. Regression: it must still work.
	# =====================================================================================
	print("-- name-list seal (Totsuka Blade regression) --")
	_seal(m, caster, subject, [], [harm_a.ability_name])
	_check(_both(harm_a, subject) == [false, false], "POSITIVE: the NAMED skill %s is unusable" % harm_a.ability_name)
	_check(_both(harm_b, subject) == [true, true], "an unnamed Harmful skill is untouched by a name-list seal")
	_check(_both(soft, subject) == [true, true], "an unnamed non-Harmful skill is untouched by a name-list seal")
	_clear_seals(subject)

	# =====================================================================================
	# 4. A CLASS FILTER THAT MATCHES NOTHING SEALS NOTHING. The failure mode this catches is the
	#    class branch falling through to the unfiltered "seal everything" case — and, with an
	#    unknown class string, classes[cls] crashing where classes.get(cls, false) does not.
	# =====================================================================================
	print("-- class filter that matches nothing --")
	_seal(m, caster, subject, ["Nonexistent Class"])
	for ab in [harm_a, harm_b, soft]:
		_check(_both(ab, subject) == [true, true],
			"a class seal matching no class leaves %s usable (no fall-through, no crash)" % ab.ability_name)
	_clear_seals(subject)

	# =====================================================================================
	# 5. "CANNOT BE IGNORED" — the stun escape hatches must not exempt anything from a seal.
	# =====================================================================================
	print("-- stun escape hatches do not apply --")
	# 5a. the `stunnable` flag (what the Unstunnable class sets).
	harm_a.stunnable = false
	_stun(m, caster, subject)
	_check(_both(harm_a, subject) == [true, true],
		"[control] an Unstunnable skill IS exempt from a real Stun")
	_seal(m, caster, subject)
	_check(_both(harm_a, subject) == [false, false],
		"POSITIVE: the same Unstunnable skill is NOT exempt from the seal")
	_clear_seals(subject)
	harm_a.stunnable = true
	_clear_type(subject, EffectType.Type.STUN)

	# 5b. shrug_off_type(STUN) — a specific ignore of STUN effects.
	_stun(m, caster, subject)
	var ign = Effect.ignore_effect_effect(6, EffectType.Type.STUN)
	ign.set_source(subject.moveset.base_abilities[0])
	Character.add_allied_effect(_ctx(m, subject), subject, subject, ign)
	_check(_both(harm_a, subject) == [true, true],
		"[control] shrug_off_type(STUN) IS exempt from a real Stun")
	_seal(m, caster, subject)
	_check(_both(harm_a, subject) == [false, false],
		"POSITIVE: shrug_off_type(STUN) does NOT exempt the skill from the seal")
	_clear_seals(subject)
	_clear_type(subject, EffectType.Type.STUN)
	_clear_type(subject, EffectType.Type.IGNORE_EFFECT)
	_check(_both(harm_a, subject) == [true, true], "the subject is fully restored after the hatch tests")

	# =====================================================================================
	# 6. CHANNELS — the one stun side effect the seal re-emits (owner ruling Q5).
	#    Maka's Witch Hunter is the live channel: its CHANNEL_CANCEL sits on Maka, sourced to
	#    Witch Hunter, and holds the target's damage/cost effects in cancel_effects.
	# =====================================================================================
	print("-- a seal still breaks the holder's channel --")
	var maka = p1.team.characters[0]
	var witch = null
	for ab in maka.moveset.base_abilities:
		if ab.ability_name == "Witch Hunter":
			witch = ab
	_check(witch != null, "found Maka's Witch Hunter")
	var victim = bystander                      # NOT the seal subject — keep the two tests disjoint
	maka.targeter.targets = [victim]
	maka.targeter.main_target = victim
	maka.used_ability = witch
	witch.execute(maka, m)
	_check(maka.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 1,
		"Witch Hunter planted a CHANNEL_CANCEL on Maka")
	_check(victim.effects.has_effect("Witch Hunter", EffectType.Type.DAMAGE, maka) != null,
		"...and the channelled damage effect on the target")

	# Control FIRST: a seal whose filter does not cover Witch Hunter must leave the channel alone.
	_seal(m, p2.team.characters[0], maka, ["Nonexistent Class"])
	_check(maka.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 1,
		"[control] a seal that does NOT lock Witch Hunter out leaves the channel running")
	_clear_seals(maka)

	_seal(m, p2.team.characters[0], maka)
	_check(maka.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 0,
		"POSITIVE: an unfiltered seal ended the CHANNEL_CANCEL")
	_check(victim.effects.has_effect("Witch Hunter", EffectType.Type.DAMAGE, maka) == null,
		"POSITIVE: ...and the channelled effects it was holding are gone from the target")
	_clear_seals(maka)

	# =====================================================================================
	# 7. JADEN — check_effect_breaking narrowed from the "Elemental HERO" prefix to a list.
	# =====================================================================================
	print("-- Jaden: base HEROes no longer tear down on a Shield break --")
	var jaden = p1.team.characters[1]
	var jfoe = p2.team.characters[2]
	var avian = jaden.moveset.base_abilities[0]
	var clayman = jaden.moveset.base_abilities[2]
	_check(avian.ability_name == "Elemental HERO Avian" and clayman.ability_name == "Elemental HERO Clayman",
		"Jaden's slots 0/2 are Avian and Clayman (%s / %s)" % [avian.ability_name, clayman.ability_name])
	jaden.targeter.targets = [jaden]
	jaden.targeter.main_target = jaden
	jaden.used_ability = avian
	avian.execute(jaden, m)
	_plant_hero_markers(m, jaden, jfoe, avian)
	_check(_markers_live(jaden, jfoe, avian.ability_name) == 2, "two Avian-named markers are live before the break")
	# Avian stopped granting a Shield in the same patch (abilities/jaden1.gd), so the Shield to
	# break has to be planted by hand. Without this the assertion below goes VACUOUS: nothing would
	# tear down simply because no break ever ran.
	var avian_shield = _shield_of(jaden, avian.ability_name)
	if avian_shield == null:
		avian_shield = Effect.shield_effect(15, 6)
		avian_shield.set_source(avian)
		Character.add_allied_effect(_ctx(m, jaden), jaden, jaden, avian_shield)
		avian_shield = _shield_of(jaden, avian.ability_name)
	_check(avian_shield != null, "an Avian-sourced Shield exists to break")
	if avian_shield != null:
		jaden.check_effect_breaking(avian_shield)
	_check(_markers_live(jaden, jfoe, avian.ability_name) == 2,
		"POSITIVE: breaking Avian's Shield tore NOTHING down (%d/2 markers survived)"
			% _markers_live(jaden, jfoe, avian.ability_name))

	# CLAYMAN JOINED THE SURVIVORS. The owner REVISED the earlier Q27 ruling on 2026-08-02: Clayman
	# keeps his Shield but is no longer torn down with it, because the TICKING_TRIGGER that
	# regenerates that Shield — not the Shield itself — is what jaden6/jaden7 gate their fusions on.
	# This block previously asserted the opposite and had to be inverted, not "fixed" in the code.
	# The regeneration half of that ruling is covered by training/tests/clayman_persist_probe.
	print("-- Jaden: only Mudballman and the fusions still tear down --")
	jaden.used_ability = clayman
	clayman.execute(jaden, m)
	_plant_hero_markers(m, jaden, jfoe, clayman)
	_check(_markers_live(jaden, jfoe, clayman.ability_name) == 2, "two Clayman-named markers are live before the break")
	var clay_shield = _shield_of(jaden, clayman.ability_name)
	_check(clay_shield != null, "Clayman granted a Shield to break")
	if clay_shield != null:
		jaden.check_effect_breaking(clay_shield)
	_check(_markers_live(jaden, jfoe, clayman.ability_name) == 2,
		"POSITIVE: breaking Clayman's Shield tears NOTHING down (%d/2 markers survived)"
			% _markers_live(jaden, jfoe, clayman.ability_name))

	var mudball = jaden.moveset.base_abilities[6]
	_check(mudball.ability_name == "Elemental HERO Mudballman", "Jaden's slot 6 is Mudballman (%s)" % mudball.ability_name)
	jaden.used_ability = mudball
	mudball.execute(jaden, m)
	_plant_hero_markers(m, jaden, jfoe, mudball)
	_check(_markers_live(jaden, jfoe, mudball.ability_name) == 2, "two Mudballman-named markers are live before the break")
	var mud_shield = _shield_of(jaden, mudball.ability_name)
	_check(mud_shield != null, "Mudballman granted a Shield to break")
	if mud_shield != null:
		jaden.check_effect_breaking(mud_shield)
	_check(_markers_live(jaden, jfoe, mudball.ability_name) == 0,
		"POSITIVE: breaking Mudballman's Shield still tears Mudballman down (%d/2 left)"
			% _markers_live(jaden, jfoe, mudball.ability_name))

	print("=== %s ===" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	get_tree().quit(0 if fails == 0 else 1)
