extends Node

# Patch 2026-08-02 — PHASE 9 VERIFICATION GATE.
#
# This is the probe the roadmap's "Verification" table asks for, built against a real
# BattleManager and asserting OBSERVABLE outcomes (a button that is dark, a number of damage
# instances, a stack count, who is in a target list) rather than "the code ran".
#
# WHY IT EXISTS ON TOP OF THE PER-CLUSTER PROBES: the cluster probes were written by the agents
# who wrote the changes, one cluster each. This one is written against the ROADMAP, covers the
# five blocking behaviours in the order the roadmap prioritises them, and is the single file a
# reversal test can be run against. Its priority order is deliberate:
#
#   1. THE SEAL      — a no-op seal compiles, loads and renders. Every seal block asserts the
#                      POSITIVE case (a Harmful skill reports usable == false) FIRST, because the
#                      negative-only form ("the exempt skill is still usable") passes perfectly
#                      against a seal that does nothing at all.
#   2. JADEN         — the hard blocker. The four fusion gates were repointed off SHIELD onto the
#                      base HEROes' TICKING_TRIGGER. If that repoint did not land, three of the
#                      four fusions are permanently dark and Jaden is unshippable — and nothing
#                      about that failure is visible at compile time.
#   3. DURATIONS     — every number here is written under the model "durations tick at the end of
#                      EVERY player's turn". An off-by-one is invisible except by counting the
#                      damage instances a window actually produces, which is what _window() does.
#   4. SOUL GEMS     — Madoka's threshold moved 15 -> 12 and gained a second faucet; Sayaka's
#                      Enraged Slash now grants TWO stacks, so she must die ON reaching her limit
#                      and must never be observable ALIVE at or past it.
#   5. BROLY         — effect_storage merges stacks unconditionally, so the cap is a guard BEFORE
#                      the add. A cap checked after the add reads a number that already includes
#                      the stack it was meant to refuse and silently does nothing.
#
# Plus the two Phase-5 rows whose nerfs are split across a script edit and a JSON edit and are
# therefore the most likely to be half-shipped: Nimaiya (invuln) and Katara (ally targeting).
#
#   godot --headless --path <repo> res://training/tests/patch_0802_verify_probe.tscn

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

# One battle per block. Effects planted by an earlier block would otherwise leak into a later
# one and turn a real regression into a pass (or vice versa).
func _battle(a, b):
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", a)
	var p2 = _build_player("BotEnemy", b)
	m.start_battle(p1, p2, true, 20260802, BattleManager.MatchType.BOT)
	# usable() gates on affordability first. An empty pool makes every "unusable under the seal"
	# assertion below vacuously true and the whole seal block would pass against a no-op seal.
	for colour in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		p1.team.energy.pool[colour] = 20
		p2.team.energy.pool[colour] = 20
	for c in p1.team.characters + p2.team.characters:
		c.refresh()
	return [m, p1.team.characters, p2.team.characters]

func _ctx(m, c):
	return QueryContext.from_game_state(c, m)

# BOTH call sites, always. usable() drives the local skill card; authoritative_usable() drives the
# `usable` flag in the wire snapshot. A change applied to one produces a button that looks live and
# is refused by the server, which is exactly the failure the shared helper was extracted to prevent.
func _both(ab, c) -> Array:
	return [ab.usable(c), ab.authoritative_usable(c)]

# execute() is driven directly rather than through the turn loop, so used_ability has to be set by
# hand (resolve_damage dereferences it). It is cleared afterwards because usable() refuses any
# character who has already acted — leaving it set would make every later usability assertion false
# for a reason that has nothing to do with what is under test.
func _cast(m, c, ab, targets):
	c.targeter.targets = targets
	c.targeter.main_target = targets[0] if targets.size() > 0 else null
	c.used_ability = ab
	ab.execute(c, m)
	c.used_ability = null

func _slot(c, idx, expected_name):
	var ab = c.moveset.base_abilities[idx]
	_check(ab.ability_name == expected_name,
		"[setup] %s slot %d is %s (found %s)" % [c.character_name, idx, expected_name, ab.ability_name])
	return ab

func _active(c, idx):
	return c.moveset.get_active_abilities(c)[idx]

# Re-runs an ability's own target() and reads back the `targeted` flags. target() returns nothing,
# so this is the only honest way to ask "what may this skill legally point at right now".
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

func _has(chars, c) -> bool:
	return c in chars

# Never assume slot 0 is Harmful. Gray's is not ("Ice, Make..." is Strategic), and a probe that
# picks a non-Harmful skill to test a HARMFUL-class seal against reports a red that is entirely
# its own fault — or, worse, a green.
func _first_harmful(c):
	for ab in c.moveset.base_abilities:
		if ab.classes.get("Harmful", false) and ab.usable(c):
			return ab
	return null

func _clear_type(c, t):
	for eff in c.effects.get_effects_by_type(t):
		c.effects.erase_effect(eff)

func _one_turn(m):
	for c in m.all_characters():
		c.effects.tick_all_effects_durations()

# Walk a ticking window and COUNT the damage instances it really produces.
#
# The ordering is the engine's, not a convenience: an effect planted on turn T does not fire on
# turn T. Two duration ticks (the owner's turn ending, then the opponent's) elapse before the
# ticker's first firing, and the effect is gone the moment its duration reaches 0. Counting this
# way is what turns "duration 5" from a number nobody can check into "exactly two delayed ticks".
func _window(m, watcher, eff, victim, max_rounds := 8) -> Array:
	var hits := []
	for r in range(max_rounds):
		_one_turn(m)
		_one_turn(m)
		if not is_instance_valid(eff) or not (eff in watcher.effects._effects):
			break
		var before = victim.health.hp
		m.execute_ticking_effect(eff)
		hits.append(before - victim.health.hp)
	return hits


func _ready():
	print("=== patch 2026-08-02 VERIFICATION GATE ===")
	_p1_seal()
	_p2_jaden()
	_p3_durations()
	_p4_soul_gems()
	_p5_broly_nimaiya_katara()
	print("=== %s ===" % ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


# =========================================================================================
# PRIORITY 1 — THE SEAL.
# =========================================================================================
func _p1_seal():
	print("-- [1] Yugi's Swords of Revealing Light --")
	var b = _battle(["yugi", "esdeath", "maka"], ["gray", "naruto", "gon"])
	var m = b[0]
	var yugi = b[1][0]
	var esdeath = b[1][1]
	var maka = b[1][2]
	var victim = b[2][0]
	var bystander = b[2][1]

	var kuriboh = _slot(yugi, 0, "Kuriboh")                       # Harmful, NOT excluded
	var dmg = _slot(yugi, 1, "Dark Magician Girl")                # excluded by name
	var swords = _slot(yugi, 2, "Swords of Revealing Light")
	var dm = _slot(yugi, 4, "Dark Magician")                      # excluded by name
	var gardna = _slot(yugi, 3, "Big Shield Gardna")              # non-Harmful

	# A Harmful skill on the far side of the board, so the seal is proved against someone who has
	# no stake in it.
	var foe_skill = _first_harmful(victim)
	_check(foe_skill != null,
		"[setup] found a usable Harmful skill on the victim (%s)"
			% [foe_skill.ability_name if foe_skill else "NONE"])
	if foe_skill == null:
		return

	# BASELINE. Without this, everything below could be "unusable" for reasons unrelated to the seal.
	for pair in [[kuriboh, yugi], [dmg, yugi], [dm, yugi], [gardna, yugi], [foe_skill, victim]]:
		_check(_both(pair[0], pair[1]) == [true, true],
			"[baseline] %s is usable from BOTH call sites before any seal" % pair[0].ability_name)

	# Swords targets allies AND enemies, so Yugi seals himself too — which is the only reason the
	# name exclusion has anything to do.
	_cast(m, yugi, swords, [victim, yugi])

	# ---- POSITIVE FIRST. Under a no-op seal this line, and only this line, still says true.
	var v = _both(foe_skill, victim)
	_check(v[0] == false,
		"POSITIVE: the sealed enemy's Harmful skill %s reports usable == false" % foe_skill.ability_name)
	_check(v[1] == false,
		"POSITIVE: ...and authoritative_usable == false (the wire snapshot agrees)")
	_check(_both(kuriboh, yugi) == [false, false],
		"POSITIVE: Yugi's own non-excluded Harmful skill Kuriboh is sealed out of both sites too")

	# ---- The exclusions.
	_check(_both(dmg, yugi) == [true, true],
		"Dark Magician Girl is name-EXCLUDED and stays usable")
	_check(_both(dm, yugi) == [true, true],
		"Dark Magician is name-EXCLUDED and stays usable")
	_check(_both(gardna, yugi) == [true, true],
		"a non-Harmful skill (Big Shield Gardna) is untouched by a Harmful-class seal")

	# ---- Control: an unsealed character is unaffected.
	var by_skill = bystander.moveset.base_abilities[0]
	_check(_both(by_skill, bystander) == [true, true],
		"[control] an UNSEALED enemy's skill is unaffected by someone else's seal")

	# ---- "Cannot be ignored": Swords is a NON-ignorable STUN now (was a skill_seal); no escape hatch exempts anything.
	print("-- [1] the STUN is non-ignorable: no escape hatch applies --")
	var stun_on_victim = null
	for eff in victim.effects.get_effects_by_type(EffectType.Type.STUN):
		if not eff.ignorable:
			stun_on_victim = eff
	_check(stun_on_victim != null, "the effect on the victim is a NON-ignorable STUN (not a skill_seal, not an ordinary stun)")
	_check(victim.effects.get_effects_by_type(EffectType.Type.MARK).filter(func(e): return e.skill_seal).size() == 0,
		"POSITIVE: Swords planted NO skill_seal MARK (it is a stun now)")
	_check(victim.is_stunned(foe_skill) == true,
		"...and is_stunned() reports it — a non-ignorable stun bypasses every hatch, which is what makes them irrelevant")

	# The `stunnable` flag is what the Unstunnable class sets. CONTROL FIRST: prove on the UNSEALED
	# bystander that the hatch genuinely exempts a skill from a real Stun. Without that, "it did not
	# exempt the skill from the seal" would be indistinguishable from a hatch that never works.
	var real_stun = Effect.stun_effect(6)
	real_stun.set_source(yugi.moveset.base_abilities[0])
	Character.add_hostile_effect(_ctx(m, yugi), yugi, bystander, real_stun)
	_check(_both(by_skill, bystander) == [false, false],
		"[control] a real Stun DOES make the bystander's skill unusable")
	by_skill.stunnable = false
	_check(_both(by_skill, bystander) == [true, true],
		"[control] ...and an Unstunnable skill IS exempt from that same Stun")
	by_skill.stunnable = true
	for eff in bystander.effects.get_effects_by_type(EffectType.Type.STUN):
		bystander.effects.erase_effect(eff)

	foe_skill.stunnable = false
	_check(_both(foe_skill, victim) == [false, false],
		"POSITIVE: the same Unstunnable flag does NOT exempt a skill from the non-ignorable stun")
	foe_skill.stunnable = true

	# shrug_off_type(STUN) — an explicit ignore of STUN effects.
	var ign = Effect.ignore_effect_effect(6, EffectType.Type.STUN)
	ign.set_source(victim.moveset.base_abilities[0])
	Character.add_allied_effect(_ctx(m, victim), victim, victim, ign)
	_check(victim.shrug_off_type(EffectType.Type.STUN),
		"[control] the victim now genuinely shrugs off STUN effects")
	_check(_both(foe_skill, victim) == [false, false],
		"POSITIVE: shrug_off_type(STUN) does NOT exempt the skill from the non-ignorable stun")

	# ---- Yugi can still end his own Swords (the roadmap names this one explicitly).
	print("-- [1] Yugi ends his own Swords with Dark Magician Girl --")
	_cast(m, yugi, dmg, [victim])
	var still_sealed := 0
	for c in m.all_characters():
		if c.effects.has_effect("Swords of Revealing Light", EffectType.Type.STUN, yugi) != null:
			still_sealed += 1
	_check(still_sealed == 0,
		"POSITIVE: Dark Magician Girl cleared Swords off every character (%d stuns left)" % still_sealed)
	_check(_both(kuriboh, yugi) == [true, true], "...so Kuriboh is usable again")

	# =====================================================================================
	# ESDEATH — the self-penalty is the same PREVENTION, not a Stun (Q9).
	# =====================================================================================
	print("-- [1] Esdeath's Mahapadma recoil is a non-ignorable Stun --")
	var maha = _slot(esdeath, 1, "Mahapadma")
	var es_skill = _slot(esdeath, 0, "Empire's Strongest")
	_check(_both(es_skill, esdeath) == [true, true], "[baseline] Esdeath's own skill is usable")
	_cast(m, esdeath, maha, [victim, bystander])
	_check(_both(foe_skill, victim) == [false, false],
		"POSITIVE: an unfiltered seal makes the victim's Harmful skill unusable")
	var soft_foe = null
	for ab in victim.moveset.base_abilities:
		if not ab.classes.get("Harmful", false):
			soft_foe = ab
			break
	if soft_foe != null:
		_check(_both(soft_foe, victim) == [false, false],
			"POSITIVE: ...and its NON-Harmful skill %s too — all three lists empty seals everything"
				% soft_foe.ability_name)
	_check(_both(es_skill, esdeath) == [true, true],
		"[control] Esdeath herself is not yet sealed — the recoil is on expiry, not on cast")

	# Expire both seals. The recoil must land exactly ONCE no matter how many expiries fire.
	for i in range(6):
		_one_turn(m)
	var recoils := 0
	for eff in esdeath.effects.get_effects_by_type(EffectType.Type.STUN):
		if not eff.ignorable:
			recoils += 1
	_check(recoils == 1,
		"POSITIVE: two stuns expiring left EXACTLY ONE recoil stun on Esdeath (%d)" % recoils)
	_check(esdeath.effects.get_effects_by_type(EffectType.Type.MARK).filter(func(e): return e.skill_seal).size() == 0,
		"POSITIVE: the recoil is a non-ignorable stun, not a skill_seal (%d seals on Esdeath)"
			% esdeath.effects.get_effects_by_type(EffectType.Type.MARK).filter(func(e): return e.skill_seal).size())
	_check(_both(es_skill, esdeath) == [false, false],
		"POSITIVE: ...and Esdeath's own skills are unusable from both call sites")

	# =====================================================================================
	# Q5 — a seal still breaks the holder's CHANNEL.
	# =====================================================================================
	print("-- [1] a seal breaks the sealed character's channel (Q5) --")
	var witch = _slot(maka, 2, "Witch Hunter")
	_cast(m, maka, witch, [bystander])
	_check(maka.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 1,
		"[setup] Witch Hunter planted a CHANNEL_CANCEL on Maka")
	_check(bystander.effects.has_effect("Witch Hunter", EffectType.Type.DAMAGE, maka) != null,
		"[setup] ...and its channelled damage effect on the target")

	# Control FIRST: a seal whose filter does not cover Witch Hunter leaves the channel running.
	var narrow = Effect.mark(6, "narrow test seal")
	narrow.skill_seal = true
	narrow.class_targets = ["Nonexistent Class"]
	narrow.name_override = "Narrow Test Seal"
	narrow.set_source(victim.moveset.base_abilities[0])
	Character.add_hostile_effect(_ctx(m, victim), victim, maka, narrow)
	_check(maka.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 1,
		"[control] a seal that does NOT lock Witch Hunter out leaves the channel running")
	maka.effects.erase_effect(narrow)

	var broad = Effect.mark(6, "broad test seal")
	broad.skill_seal = true
	broad.name_override = "Broad Test Seal"
	broad.set_source(victim.moveset.base_abilities[0])
	Character.add_hostile_effect(_ctx(m, victim), victim, maka, broad)
	_check(maka.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL).size() == 0,
		"POSITIVE: an unfiltered seal ended the CHANNEL_CANCEL")
	_check(bystander.effects.has_effect("Witch Hunter", EffectType.Type.DAMAGE, maka) == null,
		"POSITIVE: ...and the channelled effects it was holding are gone from the target")


# =========================================================================================
# PRIORITY 2 — JADEN. THE HARD BLOCKER.
# =========================================================================================
func _p2_jaden():
	print("-- [2] Jaden: all four fusions after the base HEROes lost their Shields --")
	var b = _battle(["jaden", "gon", "naruto"], ["gray", "eren", "misaka"])
	var m = b[0]
	var jaden = b[1][0]

	var avian = _slot(jaden, 0, "Elemental HERO Avian")
	var burst = _slot(jaden, 1, "Elemental HERO Burstinatrix")
	var clay = _slot(jaden, 2, "Elemental HERO Clayman")
	var bubble = _slot(jaden, 3, "Elemental HERO Bubbleman")
	_slot(jaden, 4, "Elemental HERO Flame Wingman")
	_slot(jaden, 5, "Elemental HERO Rampart Blaster")
	_slot(jaden, 6, "Elemental HERO Mudballman")
	_slot(jaden, 7, "Elemental HERO Mariner")

	# The premise of the whole repoint: three of the four base HEROes no longer grant a Shield.
	# Asserted FIRST, so a fusion that lights up cannot be doing so via the old SHIELD gate.
	for pair in [[avian, "Elemental HERO Avian"], [burst, "Elemental HERO Burstinatrix"],
			[bubble, "Elemental HERO Bubbleman"]]:
		for eff in jaden.effects._effects.duplicate():
			jaden.effects.erase_effect(eff)
		_cast(m, jaden, pair[0], [jaden])
		_check(jaden.effects.has_effect(pair[1], EffectType.Type.SHIELD, jaden) == null,
			"POSITIVE: %s grants NO Shield any more" % pair[1])
		_check(jaden.effects.has_effect(pair[1], EffectType.Type.TICKING_TRIGGER, jaden) != null,
			"POSITIVE: ...but still plants the TICKING_TRIGGER the fusion gates now read")
	for eff in jaden.effects._effects.duplicate():
		jaden.effects.erase_effect(eff)
	_cast(m, jaden, clay, [jaden])
	_check(jaden.effects.has_effect("Elemental HERO Clayman", EffectType.Type.SHIELD, jaden) != null,
		"[control] Clayman DOES keep its Shield (the deliberate asymmetry, Q27)")

	# Recipes: 4 = Avian + Burstinatrix; 5 = Clayman + Burstinatrix;
	#          6 = Clayman + Bubbleman;  7 = Avian + Bubbleman.
	var recipes = [
		[4, 0, 1, "Elemental HERO Avian", "Elemental HERO Burstinatrix"],
		[5, 2, 1, "Elemental HERO Clayman", "Elemental HERO Burstinatrix"],
		[6, 2, 3, "Elemental HERO Clayman", "Elemental HERO Bubbleman"],
		[7, 0, 3, "Elemental HERO Avian", "Elemental HERO Bubbleman"],
	]
	for r in recipes:
		var fusion = jaden.moveset.base_abilities[r[0]]
		for eff in jaden.effects._effects.duplicate():
			jaden.effects.erase_effect(eff)
		_check(fusion.extra_usable(jaden) == false,
			"[control] %s is dark with NO ingredients" % fusion.ability_name)
		_cast(m, jaden, jaden.moveset.base_abilities[r[1]], [jaden])
		_check(fusion.extra_usable(jaden) == false,
			"[control] %s is still dark with only %s" % [fusion.ability_name, r[3]])
		_cast(m, jaden, jaden.moveset.base_abilities[r[2]], [jaden])
		# THE BLOCKER. If the gate was not repointed off SHIELD, this is the line that goes red.
		_check(fusion.extra_usable(jaden) == true,
			"POSITIVE: %s LIGHTS UP on %s + %s" % [fusion.ability_name, r[3], r[4]])
		_check(_both(fusion, jaden) == [true, true],
			"POSITIVE: ...and reports usable from BOTH call sites")
		_cast(m, jaden, fusion, [jaden])
		_check(jaden.effects.has_effect(r[3], EffectType.Type.TICKING_TRIGGER, jaden) == null
				and jaden.effects.has_effect(r[4], EffectType.Type.TICKING_TRIGGER, jaden) == null,
			"...and using %s CONSUMES both ingredients" % fusion.ability_name)
		_check(fusion.extra_usable(jaden) == false,
			"...so %s cannot be used a second time" % fusion.ability_name)


# =========================================================================================
# PRIORITY 3 — DURATION-SENSITIVE CHANGES.
# =========================================================================================
func _p3_durations():
	# ---- GANTA: three Affliction instances of 5, the first one immediate.
	print("-- [3] Ganta: Woodpecker is 5 Affliction for 3 turns --")
	var b = _battle(["ganta", "inosuke", "ryuko"], ["gray", "naruto", "gon"])
	var m = b[0]
	var ganta = b[1][0]
	var inosuke = b[1][1]
	var ryuko = b[1][2]
	var foe = b[2][0]

	_slot(ganta, 4, "Branch of Sin: Woodpecker")
	var ganta_gun = _slot(ganta, 0, "Ganta Gun")
	var use_trigger = ganta.effects.has_effect("Branch of Sin: Woodpecker",
		EffectType.Type.HARMFUL_USE_TRIGGER, ganta)
	_check(use_trigger != null, "[setup] the passive's HARMFUL_USE_TRIGGER is live from startup_passives")

	var hp = ganta.health.hp
	ganta.used_ability = ganta_gun
	ganta.check_harmful_use_triggers(m, ganta_gun)
	ganta.used_ability = null
	var first = hp - ganta.health.hp
	_check(first == 5,
		"POSITIVE: the first Affliction instance is immediate and deals 5 (dealt %d)" % first)
	var dot = ganta.effects.has_effect("Branch of Sin: Woodpecker", EffectType.Type.DAMAGE, ganta)
	_check(dot != null and dot.duration == 5,
		"POSITIVE: the ticker runs duration 5 — 2N-1 for a 3-turn window (dur %s)"
			% [dot.duration if dot else "absent"])
	var hits = _window(m, ganta, dot, ganta)
	_check(hits.size() == 2,
		"POSITIVE: exactly TWO further ticks follow, so THREE instances total (saw %d: %s)"
			% [hits.size(), str(hits)])
	_check(hits == [5, 5], "POSITIVE: ...and each of them deals 5 (%s)" % str(hits))

	# ---- INOSUKE: exactly two DELAYED Bleed ticks, none on the cast turn.
	print("-- [3] Inosuke: 10 Piercing now, 10 Bleed for the following 2 turns --")
	var slash = _slot(inosuke, 0, "Double Serrated Slash")
	var fhp = foe.health.hp
	_cast(m, inosuke, slash, [foe])
	var cast_turn = fhp - foe.health.hp
	_check(cast_turn == 10,
		"POSITIVE: the cast turn deals 10 and ONLY 10 — no Bleed instance rides along (dealt %d)"
			% cast_turn)
	var bleed = foe.effects.has_effect("Double Serrated Slash", EffectType.Type.DAMAGE, inosuke)
	_check(bleed != null and bleed.duration == 5,
		"POSITIVE: the Bleed rider runs duration 5 — 2N+1 for a purely delayed 2-turn window (dur %s)"
			% [bleed.duration if bleed else "absent"])
	var bleeds = _window(m, foe, bleed, foe)
	_check(bleeds.size() == 2,
		"POSITIVE: exactly TWO delayed Bleed ticks, no more (saw %d: %s)" % [bleeds.size(), str(bleeds)])
	_check(bleeds == [10, 10], "POSITIVE: ...each for 10 (%s)" % str(bleeds))

	# ---- RYUKO: Fiber Lost is on cooldown for exactly 1 turn under Decapitation Mode, 0 without.
	print("-- [3] Ryuko: Fiber Lost's cooldown under Decapitation Mode --")
	var fiber = _slot(ryuko, 0, "Fiber Lost")
	var decap = _slot(ryuko, 1, "Decapitation Mode")
	# Control FIRST, so "1 turn under the mode" is measured against a known 0.
	fiber.cooldown_remaining = 0
	fiber.start_cooldown()
	ryuko.moveset.advance_cooldowns(ryuko)
	_check(fiber.cooldown_remaining == 0,
		"[control] without Decapitation Mode, Fiber Lost settles on 0 turns of cooldown (is %d)"
			% fiber.cooldown_remaining)
	_cast(m, ryuko, decap, [ryuko])
	_check(ryuko.effects.has_effect("Decapitation Mode", EffectType.Type.COOLDOWN_MOD, ryuko) != null,
		"[setup] Decapitation Mode planted a COOLDOWN_MOD")
	fiber.cooldown_remaining = 0
	fiber.start_cooldown()
	ryuko.moveset.advance_cooldowns(ryuko)
	_check(fiber.cooldown_remaining == 1,
		"POSITIVE: under Decapitation Mode, Fiber Lost is on cooldown for exactly 1 turn (is %d)"
			% fiber.cooldown_remaining)
	# The mod names Fiber Lost ONLY (Q18): Life Fiber Synchronization must not inherit it.
	var lfs = _slot(ryuko, 2, "Life Fiber Synchronization")
	lfs.cooldown_remaining = 0
	var lfs_printed = lfs.cooldown
	lfs.start_cooldown()
	ryuko.moveset.advance_cooldowns(ryuko)
	_check(lfs.cooldown_remaining == lfs_printed,
		"[control] Life Fiber Synchronization keeps its own printed cooldown %d (is %d) — the mod names Fiber Lost only"
			% [lfs_printed, lfs.cooldown_remaining])
	# Toggling the mode off tears the cooldown penalty down with the rest of it.
	_cast(m, ryuko, decap, [ryuko])
	_check(ryuko.effects.has_effect("Decapitation Mode", EffectType.Type.COOLDOWN_MOD, ryuko) == null,
		"toggling Decapitation Mode off removes the cooldown penalty with the rest of the mode")

	# ---- LUCY: 2 turns vs 3, and the Gemini damage repeat is Gemini-ONLY.
	print("-- [3] Lucy: Aquarius 2 turns vs 3 under Gemini --")
	var b2 = _battle(["lucy", "itachi", "shokuhou"], ["gray", "naruto", "gon"])
	var m2 = b2[0]
	var lucy = b2[1][0]
	var itachi = b2[1][1]
	var shokuhou = b2[1][2]
	var lucy_ally = b2[1][1]
	var lucy_foe = b2[2][0]

	var aquarius = _slot(lucy, 0, "Aquarius")
	_cast(m2, lucy, aquarius, [lucy_foe, lucy_ally])
	var dr = lucy_ally.effects.has_effect("Aquarius", EffectType.Type.DAMAGE_REDUCTION, lucy)
	_check(dr != null and dr.duration == 4,
		"POSITIVE: a NON-Gemini cast grants 2 turns of Damage Reduction (dur %s, expect 4)"
			% [dr.duration if dr else "absent"])
	# THE `== 4` REGRESSION. Once the base duration became 4, a gate written as `duration == 4`
	# is true for every cast and hands the Gemini repeat out for free. Nothing logs it.
	_check(lucy_foe.effects.has_effect("Aquarius", EffectType.Type.DAMAGE, lucy) == null,
		"POSITIVE: a NON-Gemini cast plants NO damage repeat (this is the `duration == 4` regression)")

	# has_effect returns the FIRST match, so the dur-4 rider from the cast above would shadow the
	# dur-6 one and the Gemini assertion would read the non-Gemini number. Clear the board first.
	_clear_type(lucy_ally, EffectType.Type.DAMAGE_REDUCTION)
	_clear_type(lucy_foe, EffectType.Type.DAMAGE)
	var gemini_mark = Effect.mark(6, "Gemini test mark")
	gemini_mark.set_source(_slot(lucy, 1, "Gemini"))
	Character.add_allied_effect(_ctx(m2, lucy), lucy, lucy, gemini_mark)
	_check(lucy.marked_by("Gemini", lucy), "[setup] Lucy is now marked by Gemini")
	_cast(m2, lucy, aquarius, [lucy_foe, lucy_ally])
	var dr2 = lucy_ally.effects.has_effect("Aquarius", EffectType.Type.DAMAGE_REDUCTION, lucy)
	_check(dr2 != null and dr2.duration == 6,
		"POSITIVE: under Gemini the Damage Reduction runs 3 turns (dur %s, expect 6)"
			% [dr2.duration if dr2 else "absent"])
	var repeat = lucy_foe.effects.has_effect("Aquarius", EffectType.Type.DAMAGE, lucy)
	_check(repeat != null and repeat.duration == 5,
		"POSITIVE: ...and the damage repeat IS planted, at duration 5 — 2N-1 for 3 total turns (dur %s)"
			% [repeat.duration if repeat else "absent"])

	# ---- ITACHI: Kotoamatsukami runs 2 turns in BOTH branches.
	print("-- [3] Itachi: Kotoamatsukami is 2 turns on both sides --")
	var koto = _slot(itachi, 2, "Kotoamatsukami")
	_cast(m2, itachi, koto, [lucy_foe])
	var use_ctr = lucy_foe.effects.has_effect("Kotoamatsukami", EffectType.Type.COUNTER_USE, itachi)
	_check(use_ctr != null and use_ctr.duration == 4,
		"POSITIVE: the hostile COUNTER_USE branch runs 2 turns (dur %s, expect 4)"
			% [use_ctr.duration if use_ctr else "absent"])
	_cast(m2, itachi, koto, [lucy])
	var recv_ctr = lucy.effects.has_effect("Kotoamatsukami", EffectType.Type.COUNTER_RECEIVE, itachi)
	_check(recv_ctr != null and recv_ctr.duration == 4,
		"POSITIVE: the allied COUNTER_RECEIVE branch runs 2 turns too (dur %s, expect 4)"
			% [recv_ctr.duration if recv_ctr else "absent"])

	# ---- SHOKUHOU: the 10 Piercing lands on the CAST turn, and the window follows Exterior.
	print("-- [3] Shokuhou: Mental Out's cast-turn tick, with and without Exterior --")
	var mental = _slot(shokuhou, 0, "Mental Out")
	var exterior = _slot(shokuhou, 2, "Exterior")
	var mo_foe = b2[2][1]
	var before_hp = mo_foe.health.hp
	_cast(m2, shokuhou, mental, [mo_foe])
	_check(before_hp - mo_foe.health.hp == 10,
		"POSITIVE: Mental Out deals its 10 Piercing on the CAST turn (dealt %d)"
			% (before_hp - mo_foe.health.hp))
	var mo_tick = mo_foe.effects.has_effect("Mental Out", EffectType.Type.DAMAGE, shokuhou)
	var mo_stun = mo_foe.effects.has_effect("Mental Out", EffectType.Type.STUN, shokuhou)
	_check(mo_tick != null and mo_stun != null and mo_tick.duration == mo_stun.duration,
		"POSITIVE: the damage window matches the stun window (%s vs %s)"
			% [mo_tick.duration if mo_tick else "absent", mo_stun.duration if mo_stun else "absent"])
	_check(mo_stun != null and mo_stun.duration == 3,
		"[control] without Exterior that window is 3 (is %s)" % [mo_stun.duration if mo_stun else "absent"])

	var mo_foe2 = b2[2][2]
	var ext_mark = Effect.mark(6, "Exterior test mark")
	ext_mark.set_source(exterior)
	Character.add_allied_effect(_ctx(m2, shokuhou), shokuhou, shokuhou, ext_mark)
	_check(shokuhou.marked_by("Exterior"), "[setup] Shokuhou is marked by Exterior")
	before_hp = mo_foe2.health.hp
	_cast(m2, shokuhou, mental, [mo_foe2])
	_check(before_hp - mo_foe2.health.hp == 10,
		"POSITIVE: the cast-turn tick still lands with Exterior up (dealt %d)"
			% (before_hp - mo_foe2.health.hp))
	var e_tick = mo_foe2.effects.has_effect("Mental Out", EffectType.Type.DAMAGE, shokuhou)
	var e_stun = mo_foe2.effects.has_effect("Mental Out", EffectType.Type.STUN, shokuhou)
	_check(e_stun != null and e_stun.duration == 7,
		"POSITIVE: with Exterior CONSUMED the window is 7, not 3 (is %s)"
			% [e_stun.duration if e_stun else "absent"])
	_check(e_tick != null and e_tick.duration == 7,
		"POSITIVE: and the damage window is extended with it, not left at 3 (is %s)"
			% [e_tick.duration if e_tick else "absent"])
	_check(not shokuhou.marked_by("Exterior"), "Exterior was consumed by the cast")

	# ---- SASUKE: permanent Kirin swap, and Kirin swapping back once used (Q28).
	print("-- [3] Sasuke: the Kirin swap is permanent and retires itself --")
	var b3 = _battle(["sasuke", "naruto", "gon"], ["gray", "eren", "misaka"])
	var m3 = b3[0]
	var sasuke = b3[1][0]
	var s_foe = b3[2][0]
	var gdf = _slot(sasuke, 2, "Great Dragon Fire")
	_cast(m3, sasuke, gdf, [s_foe])
	var mark = s_foe.effects.has_effect("Great Dragon Fire", EffectType.Type.MARK, sasuke)
	_check(mark != null and mark.duration == -1,
		"POSITIVE: the enemy mark is permanent (dur %s, expect -1)" % [mark.duration if mark else "absent"])
	_check(_active(sasuke, 2).ability_name == "Great Dragon Fire",
		"[control] slot 2 is still Great Dragon Fire before the delay expires")
	for i in range(4):
		_one_turn(m3)
	_check(_active(sasuke, 2).ability_name == "Kirin",
		"POSITIVE: after the delay, slot 2 is Kirin (is %s)" % _active(sasuke, 2).ability_name)
	# The old window was 2 durations. Burn well past it: a fixed swap would have reverted by now.
	for i in range(10):
		_one_turn(m3)
	_check(_active(sasuke, 2).ability_name == "Kirin",
		"POSITIVE: Kirin is STILL in slot 2 long after the old 2-duration window (is %s)"
			% _active(sasuke, 2).ability_name)
	var kirin = _active(sasuke, 2)
	_cast(m3, sasuke, kirin, [s_foe])
	_check(_active(sasuke, 2).ability_name == "Great Dragon Fire",
		"POSITIVE: using Kirin hands slot 2 back to Great Dragon Fire (is %s)"
			% _active(sasuke, 2).ability_name)
	_check(kirin.extra_usable(sasuke) == false,
		"...and Kirin refuses a second use, so the slot could not be left holding a spent skill")


# =========================================================================================
# PRIORITY 4 — MADOKA / SAYAKA DEATH THRESHOLDS.
# =========================================================================================
func _p4_soul_gems():
	print("-- [4] Madoka: per-turn faucet and the 12 threshold --")
	var b = _battle(["madoka", "sayaka", "gon"], ["gray", "naruto", "misaka"])
	var m = b[0]
	var madoka = b[1][0]
	var sayaka = b[1][1]
	var foe = b[2][0]

	_slot(madoka, 4, "Soul Gem: Madoka")
	var gem = madoka.effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK, madoka)
	var ticker = madoka.effects.has_effect("Soul Gem: Madoka", EffectType.Type.TICKING_TRIGGER, madoka)
	_check(gem != null, "[setup] the Soul Gem mark exists from startup_passives")
	_check(ticker != null, "POSITIVE: the per-turn TICKING_TRIGGER exists (the new faucet)")
	_check(ticker != null and ticker.remove_on_death == false and ticker.system,
		"POSITIVE: ...and it survives a death cleanse (system=%s remove_on_death=%s)"
			% [ticker.system if ticker else "?", ticker.remove_on_death if ticker else "?"])
	_check(gem != null and gem.mag == 0, "[setup] the gem starts at 0 (is %s)" % [gem.mag if gem else "?"])

	m.execute_ticking_effect(ticker)
	_check(gem.mag == 1, "POSITIVE: one tick == exactly one stack (is %d)" % gem.mag)

	# GDScript runtime errors log and continue: a ticker that null-derefs a missing gem would show
	# up as a dead passive plus stderr spam, never as a failed assertion. Force the case.
	madoka.effects.erase_effect(gem)
	_check(madoka.effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK, madoka) == null,
		"[setup] the gem has been removed, as a death cleanse would")
	m.execute_ticking_effect(ticker)
	var reseeded = madoka.effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK, madoka)
	_check(reseeded != null,
		"POSITIVE: a gemless tick RE-SEEDS the gem instead of crashing (mag %s)"
			% [reseeded.mag if reseeded else "absent"])

	# Walk to the threshold by ticking. The gem is death-cleansed, so the count has to be read
	# BEFORE the fatal tick — reading it after gives null and the assertion would be unfalsifiable.
	# She must die on the tick that takes her from 11 to 12: not the old 15, and not one early.
	var last_alive := -1
	var ticks := 0
	for i in range(20):
		var g = madoka.effects.has_effect("Soul Gem: Madoka", EffectType.Type.MARK, madoka)
		last_alive = g.mag if g != null else -1
		m.execute_ticking_effect(ticker)
		ticks += 1
		if madoka.dead:
			break
	_check(madoka.dead,
		"POSITIVE: the per-turn faucet ALONE eventually kills Madoka (after %d ticks)" % ticks)
	_check(last_alive == 11,
		"POSITIVE: she was alive at 11 and died on the tick that made it 12 — not the old 15 (last live count %d)"
			% last_alive)

	# ---- SAYAKA: Enraged Slash grants TWO stacks, and she is never observable alive at the limit.
	print("-- [4] Sayaka: Enraged Slash grants 2 stacks and kills ON 10 --")
	_slot(sayaka, 4, "Soul Gem: Sayaka")
	var slash = _slot(sayaka, 3, "Enraged Slash")
	var sgem = sayaka.effects.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK, sayaka)
	_check(sgem != null, "[setup] Sayaka's Soul Gem exists from startup_passives")
	_check(sgem.mag == 0, "[setup] it starts at 0 (is %d)" % sgem.mag)
	_cast(m, sayaka, slash, [foe])
	_check(sgem.mag == 2,
		"POSITIVE: one Enraged Slash grants exactly 2 stacks (is %d)" % sgem.mag)
	_check(not sayaka.dead, "[control] 2 stacks is nowhere near lethal — she is alive")

	# From 8, one cast takes her to exactly 10 and must kill her.
	# INSTRUMENTATION, not a behaviour change. The gem is death-cleansed by design
	# (cleanse_death_effects branch 1 takes any effect whose user is the dying character unless it
	# is system AND remove_on_death=false), which would leave the final count unreadable and make
	# "she is never past the limit" pass against ANY number, 11 included. These two flags pin the
	# gem in place for the measurement; neither is read by gain_corruption's arithmetic.
	sgem.mag = 8
	sgem.system = true
	sgem.remove_on_death = false
	_cast(m, sayaka, slash, [foe])
	var s_after = sayaka.effects.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK, sayaka)
	_check(sayaka.dead, "POSITIVE: from 8 stacks, Enraged Slash's 2 stacks kill her")
	_check(s_after != null and s_after.mag == 10,
		"POSITIVE: and she stops at exactly the lethal 10, never visibly past it (mag %s)"
			% [s_after.mag if s_after else "gem gone"])

	# From 9 the second grant must be SKIPPED — the death check runs BETWEEN the two stacks.
	var b2 = _battle(["sayaka", "madoka", "gon"], ["gray", "naruto", "misaka"])
	var m2 = b2[0]
	var sayaka2 = b2[1][0]
	var foe2 = b2[2][0]
	var slash2 = sayaka2.moveset.base_abilities[3]
	var gem2 = sayaka2.effects.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK, sayaka2)
	gem2.mag = 9
	gem2.system = true            # same instrumentation as above — keeps the count readable post-mortem
	gem2.remove_on_death = false
	_cast(m2, sayaka2, slash2, [foe2])
	var gem2_after = sayaka2.effects.has_effect("Soul Gem: Sayaka", EffectType.Type.MARK, sayaka2)
	_check(sayaka2.dead, "POSITIVE: from 9 stacks the FIRST of the two stacks already kills her")
	# THE Q38 LINE. The two grants are two separate gain_corruption() calls precisely so the death
	# check runs BETWEEN them. One grant of 2 would leave a dead Sayaka reading 11.
	_check(gem2_after != null and gem2_after.mag == 10,
		"POSITIVE: the second stack is SKIPPED — she stops at exactly 10, never 11 (mag %s)"
			% [gem2_after.mag if gem2_after else "gem gone"])


# =========================================================================================
# PRIORITY 5 — BROLY'S CAP, plus the two half-shipped-risk Phase-5 rows.
# =========================================================================================
func _p5_broly_nimaiya_katara():
	print("-- [5] Broly: Legendary Super Saiyan caps at 4 stacks --")
	var b = _battle(["nimaiya", "kitara", "gon"], ["broly", "naruto", "gray"])
	var m = b[0]
	var nimaiya = b[1][0]
	var katara = b[1][1]
	var ally = b[1][2]
	var broly = b[2][0]
	var foe2 = b[2][1]

	_slot(broly, 4, "Legendary Super Saiyan")
	var watcher = broly.effects.has_effect("Legendary Super Saiyan",
		EffectType.Type.HARMFUL_RECEIVE_TRIGGER, broly)
	_check(watcher != null, "[setup] Broly's HARMFUL_RECEIVE_TRIGGER is live from startup_passives")

	var attacker_skill = nimaiya.moveset.base_abilities[0]
	var seen := []
	for i in range(6):
		nimaiya.used_ability = attacker_skill
		nimaiya.targeter.targets = [broly]
		nimaiya.targeter.main_target = broly
		broly.check_harmful_receive_triggers(m, attacker_skill, true)
		var lss = broly.effects.has_effect("Legendary Super Saiyan", EffectType.Type.DAMAGE_MOD, broly)
		seen.append(lss.stack_count() if lss else 0)
	nimaiya.used_ability = null
	_check(seen.size() >= 5 and seen[3] == 4,
		"POSITIVE: the 4th Harmful skill received puts him on 4 stacks (%s)" % str(seen))
	_check(seen[4] == 4 and seen[5] == 4,
		"POSITIVE: the 5th and 6th attempts do NOT raise stack_count() past 4 (%s)" % str(seen))
	_check(broly.effects.has_effect("Legendary Super Saiyan", EffectType.Type.ABILITY_SWAP, broly) != null,
		"...and the Planet Geyser ascension still fires at that same 4")

	# ---- NIMAIYA: the nerf is split across a script edit (the targeting flag) and a JSON edit
	#      (the "Bypassing" class). _skill_pierces_invuln short-circuits on the class alone, so a
	#      missing JSON half leaves the skill piercing on the reflect-retarget path only — silently.
	print("-- [5] Nimaiya: Unblockable Strike no longer pierces Invulnerability --")
	var strike = _slot(nimaiya, 0, "Unblockable Strike")
	_check(strike.classes.get("Bypassing", false) == false,
		"POSITIVE: the Bypassing CLASS is off the row — the half that the reflect path reads")
	_check(_has(_targets_of(m, nimaiya, strike), broly),
		"[control] a normal enemy IS targetable by Unblockable Strike")
	var invuln = Effect.invuln_effect(6)
	invuln.set_source(broly.moveset.base_abilities[0])
	Character.add_allied_effect(_ctx(m, broly), broly, broly, invuln)
	_check(broly.is_invuln(strike), "[setup] Broly is now genuinely Invulnerable to this skill")
	_check(not _has(_targets_of(m, nimaiya, strike), broly),
		"POSITIVE: an Invulnerable enemy is NOT targetable — the normal path")
	_check(_has(_targets_of(m, nimaiya, strike), foe2),
		"[control] ...while his non-invulnerable teammate still is")

	# The reflect-retarget path reads a DIFFERENT bypass source. Prove it spares an invuln
	# teammate, and prove the control by forcing the class back on for one call.
	var inv_ally = Effect.invuln_effect(6)
	inv_ally.set_source(ally.moveset.base_abilities[0])
	Character.add_allied_effect(_ctx(m, ally), ally, ally, inv_ally)
	nimaiya.used_ability = strike
	var bounced = strike.reflect_retarget_to_team(nimaiya)
	_check(not _has(bounced, ally),
		"POSITIVE: a reflected Unblockable Strike SPARES the invulnerable teammate")
	strike.classes["Bypassing"] = true
	var bounced_bypass = strike.reflect_retarget_to_team(nimaiya)
	strike.classes["Bypassing"] = false
	_check(_has(bounced_bypass, ally),
		"[control] with Bypassing forced back on it DOES hit them — so the line above is not vacuous")
	nimaiya.used_ability = null

	# ---- KATARA: Ice Deflection is an ALLY-targeted skill now, and Q19 is recorded as "no".
	print("-- [5] Katara: Ice Deflection targets an ally; isolated, she cannot protect herself --")
	var deflect = _slot(katara, 1, "Ice Deflection")
	_check(deflect.classes.get("Helpful", false),
		"POSITIVE: the Helpful class landed on the row (Q19)")
	var tl = _targets_of(m, katara, deflect)
	_check(_has(tl, foe2) == false, "[control] Ice Deflection cannot be aimed at an enemy")
	_check(_has(tl, ally),
		"POSITIVE: Ice Deflection can be aimed at an ALLY (%d targets)" % tl.size())
	_check(_has(tl, katara),
		"[control] and at Katara herself while she is NOT isolated — so the next line is not vacuous")
	_cast(m, katara, deflect, [ally])
	_check(ally.effects.has_effect("Ice Deflection", EffectType.Type.REFLECT_RECEIVE, katara) != null,
		"POSITIVE: the reflect actually lands ON THE ALLY, not on Katara")

	var iso = Effect.isolate(6)
	iso.set_source(foe2.moveset.base_abilities[0])
	Character.add_hostile_effect(_ctx(m, foe2), foe2, katara, iso)
	_check(katara.is_isolated(), "[setup] Katara is now Isolated")
	_check(not _has(_targets_of(m, katara, deflect), katara),
		"POSITIVE: an isolated Katara can NO LONGER protect herself — Q19 answered 'no'")

	# ---- YUBEL: the row the Data phase reported as unshipped. It has since landed; this is the
	#      assertion that keeps it landed. is_isolated() gates Helpful targeting AND both healing
	#      entry points, so the whole change is only observable as "she is a legal Helpful target".
	print("-- [5] Yubel is no longer permanently Isolated --")
	var yb = _battle(["yubel", "kitara", "gon"], ["gray", "naruto", "misaka"])
	var mb = yb[0]
	var yubel = yb[1][0]
	var y_katara = yb[1][1]
	# Prove the passive actually RAN first. "No Isolate effects" is trivially true of a passive that
	# never executed, which would make the next two lines the emptiest kind of green.
	_check(yubel.effects.get_effects_by_type(EffectType.Type.IGNORE_NON_DAMAGE).size() > 0,
		"[setup] her passive ran — its ignore-non-damage machinery is on the board")
	_check(yubel.effects.get_effects_by_type(EffectType.Type.ISOLATE).size() == 0,
		"POSITIVE: her passive plants NO Isolate at all (%d found)"
			% yubel.effects.get_effects_by_type(EffectType.Type.ISOLATE).size())
	_check(not yubel.is_isolated(), "POSITIVE: ...so is_isolated() is false")
	var soothing = _slot(y_katara, 2, "Soothing Water")
	_check(_has(_targets_of(mb, y_katara, soothing), yubel),
		"POSITIVE: an ally's Helpful skill can now legally target Yubel — the observable half of the change")
