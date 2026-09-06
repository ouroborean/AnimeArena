extends Node

# Stark kit probe. His identity is a metered damage redirect, which only exists inside the real
# damage pipeline, so the redirect checks deal REAL damage through Character.resolve_damage rather
# than poking HP. The swap contest is driven by real board changes.
#   godot --headless --path <repo> res://training/tests/stark_kit_probe.tscn

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

func _cast(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.used_ability = ab
	ab.execute(caster, m)
	return ab

func _pass_turn(m):
	m.end_of_turn_effect_handling()

# One full turn for the ACTING side, modelling the real order: the engine snapshots that side's
# ticking effects BEFORE its abilities execute, then runs them, then closes the turn. Sampling any
# other way makes an effect look like it fires on the turn it was cast, which it never does.
func _turn(m, action = null):
	var snap := []
	var info = m.get_ticking_effect_information(m.waiting_for_turn)
	for key in info:
		for eff in info[key]:
			snap.append(eff)
	if action != null:
		action.call()
	for eff in snap:
		m.execute_ticking_effect(eff)
	m.end_of_turn_effect_handling()

func _to_stark_turn(m):
	for _i in range(4):
		if not m.waiting_for_turn:
			return
		m.end_of_turn_effect_handling()

# Deal real damage FROM an enemy TO a character, through the normal ability pipeline so the
# redirect hook actually runs.
func _hit(m, attacker, victim, amount):
	var ab = attacker.moveset.base_abilities[0]
	attacker.used_ability = ab
	attacker.targeter.targets = [victim]
	attacker.targeter.main_target = victim
	var ctx = QueryContext.from_game_state(attacker, m)
	Character.resolve_damage(ctx, victim, amount, DamageType.Type.NORMAL)

# ONE skill hitting several characters: the targeter carries the whole list and every hit shares one
# used_ability, which is exactly the per-skill identity Superhuman Resilience splits its pool across.
# `pairs` is [[victim, amount], ...], damaged in list order.
func _hit_many(m, attacker, pairs):
	var victims := []
	for pr in pairs:
		victims.append(pr[0])
	_hit_skill(m, attacker, victims, pairs)

# Like _hit_many, but the TARGET LIST and the actual damage events are given separately, so a test
# can model a skill that hits one target twice, or that lists a target it never damages (shielded to
# zero, Invulnerable, ignoring damage). Both are cases where a participant count fixed up front
# would misallocate the pool.
func _hit_skill(m, attacker, targets, pairs):
	var ab = attacker.moveset.base_abilities[0]
	attacker.used_ability = ab
	attacker.targeter.targets = targets
	attacker.targeter.main_target = targets[0]
	var ctx = QueryContext.from_game_state(attacker, m)
	for pr in pairs:
		Character.resolve_damage(ctx, pr[0], pr[1], DamageType.Type.NORMAL)

func _revive(p):
	for c in p.team.characters:
		c.dead = false
		c.banished = false
		c.health.hp = c.health.max_hp

func _slot(s, i) -> String:
	var a = s.moveset.get_active_abilities(s)
	return a[i].ability_name if i < a.size() and a[i] != null else "<none>"

func _ready():
	print("=== stark kit probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["stark", "naruto", "gon"])
	var p2 = _build_player("BotEnemy", ["killua", "misaka", "gray"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	var s = p1.team.characters[0]
	var a1 = p1.team.characters[1]
	var a2 = p1.team.characters[2]
	var foe = p2.team.characters[0]
	var foe2 = p2.team.characters[1]

	# ---- registration ----
	_check(s.character_name == "Stark", "character builds (%s)" % s.character_name)
	_check(s.health.max_hp == 100, "max HP is 100")
	var names: Array = []
	for ab in s.moveset.base_abilities:
		names.append(ab.ability_name)
	_check(names == ["To The Rescue", "Axe Smash", "Cowardice", "Tumble", "Superhuman Resilience", "Cleaving Light", "Lightning Strike"],
		"7 abilities in order: %s" % [names])
	var display: Array = []
	for ab in s.moveset.display_abilities():
		display.append(ab.ability_name)
	_check(display.size() == 4 and not "Cleaving Light" in display and not "Lightning Strike" in display,
		"4 display slots, both swap-ins hidden (%s)" % [display])

	# ---- Superhuman Resilience: a SHARED 20 per turn ----
	var brands := 0
	for ally in [a1, a2]:
		for e in ally.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT):
			if e.user == s:
				brands += 1
	_check(brands == 2, "the passive branded both allies (got %d)" % brands)
	_check(s.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT).is_empty(),
		"...and did NOT brand Stark himself")

	var s_hp = s.health.hp
	var a_hp = a1.health.hp
	_hit(m, foe, a1, 30)
	_check(a_hp - a1.health.hp == 10, "ally took 30-20 = 10 (took %d)" % (a_hp - a1.health.hp))
	_check(s_hp - s.health.hp == 20, "Stark absorbed 20 (took %d)" % (s_hp - s.health.hp))

	# The budget is SHARED and now spent: a second ally eats the next hit in full.
	var a2_hp = a2.health.hp
	s_hp = s.health.hp
	_hit(m, foe, a2, 30)
	_check(a2_hp - a2.health.hp == 30, "the pool is shared and spent, so ally 2 took all 30 (took %d)" % (a2_hp - a2.health.hp))
	_check(s.health.hp == s_hp, "Stark absorbed nothing more this turn")

	# It refills next turn.
	_pass_turn(m)
	_revive(p1)
	a_hp = a1.health.hp
	s_hp = s.health.hp
	_hit(m, foe, a1, 30)
	_check(a_hp - a1.health.hp == 10 and s_hp - s.health.hp == 20, "the pool refilled on the next turn")

	# A smaller hit only moves what it needs.
	_pass_turn(m)
	_revive(p1)
	a_hp = a1.health.hp
	s_hp = s.health.hp
	_hit(m, foe, a1, 8)
	_check(a_hp - a1.health.hp == 0 and s_hp - s.health.hp == 8, "an 8 damage hit moved entirely onto Stark")

	# ---- the pool is SPLIT across everyone hit by the SAME skill (owner ruling) ----
	# Before this, an AoE resolved its targets in order and the first protected ally swallowed the
	# whole 20, leaving the second completely uncovered. 20 across 2 branded allies = 10 each.
	_pass_turn(m)
	_revive(p1)
	a_hp = a1.health.hp
	a2_hp = a2.health.hp
	s_hp = s.health.hp
	_hit_many(m, foe, [[a1, 25], [a2, 10]])
	_check(a_hp - a1.health.hp == 15, "split: the 25 hit lost only its 10 share (ally took %d, want 15)" % (a_hp - a1.health.hp))
	_check(a2_hp - a2.health.hp == 0, "split: the SECOND ally still got covered (took %d, want 0)" % (a2_hp - a2.health.hp))
	_check(s_hp - s.health.hp == 20, "split: Stark still absorbed exactly 20 in total (took %d)" % (s_hp - s.health.hp))

	# A share the first ally does not need rolls forward to the next one rather than being dropped.
	_pass_turn(m)
	_revive(p1)
	a_hp = a1.health.hp
	a2_hp = a2.health.hp
	s_hp = s.health.hp
	_hit_many(m, foe, [[a1, 4], [a2, 30]])
	_check(a_hp - a1.health.hp == 0, "rollover: the small hit was absorbed whole (ally took %d)" % (a_hp - a1.health.hp))
	_check(a2_hp - a2.health.hp == 14, "rollover: the big hit drew the unused 6 too, 30-16 (took %d, want 14)" % (a2_hp - a2.health.hp))
	_check(s_hp - s.health.hp == 20, "rollover: still exactly 20 onto Stark (took %d)" % (s_hp - s.health.hp))

	# An indivisible pool goes to the LATER share rather than being dropped: 21 across 2 = 10 then 11.
	_pass_turn(m)
	_revive(p1)
	var res = s.moveset.base_abilities[4]
	res.remaining = 21
	a_hp = a1.health.hp
	a2_hp = a2.health.hp
	s_hp = s.health.hp
	_hit_many(m, foe, [[a1, 40], [a2, 40]])
	_check(a_hp - a1.health.hp == 30, "remainder: first share is floor(21/2) = 10 (ally took %d)" % (a_hp - a1.health.hp))
	_check(a2_hp - a2.health.hp == 29, "remainder: the odd point lands on the second share, 11 (took %d)" % (a2_hp - a2.health.hp))
	_check(s_hp - s.health.hp == 21, "remainder: all 21 moved, none dropped (took %d)" % (s_hp - s.health.hp))

	# A DoT tick is not "a skill" and has nobody to share with, so it draws the whole remaining pool
	# even when the same attacker used a skill this turn. (Effect damage carries an Effect as its
	# origin, not an Ability, so the split branch is skipped entirely.)
	_pass_turn(m)
	_revive(p1)
	a_hp = a1.health.hp
	s_hp = s.health.hp
	var dot = Effect.damage_effect(30, DamageType.Type.NORMAL, 5)
	dot.set_source(foe.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(foe, m), foe, a1, dot)
	foe.targeter.targets = [a1, a2]              # a stale multi-target list from an earlier skill
	foe.used_ability = foe.moveset.base_abilities[0]
	Character.resolve_effect_damage(QueryContext.from_game_state(foe, m), dot, a1, 30, DamageType.Type.NORMAL)
	_check(a_hp - a1.health.hp == 10, "DoT: a tick draws the FULL pool, not a share (ally took %d, want 10)" % (a_hp - a1.health.hp))
	_check(s_hp - s.health.hp == 20, "DoT: Stark absorbed the full 20 (took %d)" % (s_hp - s.health.hp))
	dot.end_effect()

	# A skill that hits the SAME ally twice (nonon5 does this: once as the main target, once for the
	# Overture Barrage mark) must still leave a share for the ally behind it. A fixed up-front
	# divisor handed the repeat draw the "last participant" slice and drained the pool.
	_pass_turn(m)
	_revive(p1)
	a_hp = a1.health.hp
	a2_hp = a2.health.hp
	s_hp = s.health.hp
	_hit_skill(m, foe, [a1, a2], [[a1, 10], [a1, 10], [a2, 10]])
	_check(s_hp - s.health.hp == 20, "repeat: Stark still absorbed exactly 20 (took %d)" % (s_hp - s.health.hp))
	_check(a2_hp - a2.health.hp == 5,
		"repeat: the second ally was NOT starved by the double hit (took %d, want 5)" % (a2_hp - a2.health.hp))
	_check(a_hp - a1.health.hp == 5, "repeat: the doubly-hit ally took 5 (took %d)" % (a_hp - a1.health.hp))

	# A target the damage pipeline never reaches must not reserve a slice. The skill lists AND
	# ATTACKS both allies, but the first is ignoring damage, so resolve_damage drops his hit before
	# check_damage_redirect is ever consulted — he must neither take damage nor hold half the pool,
	# leaving the second ally to draw the WHOLE 20. (Listing a1 as a target and simply never
	# damaging him made "the untouched ally took nothing" unfalsifiable: a1's HP could not move
	# under ANY implementation. Actually running him through resolve_damage is what gives it teeth.
	# It has to be IGNORE_DAMAGE rather than INVULN, too: invulnerability is enforced at TARGETING
	# time, so it does not stop a direct resolve_damage the way is_ignoring_damage does.)
	_pass_turn(m)
	_revive(p1)
	var a1_ign = Effect.ignore_damage_effect(4)
	a1_ign.set_source(s.moveset.base_abilities[3])
	Character.add_allied_effect(QueryContext.from_game_state(a1, m), a1, a1, a1_ign)
	_check(a1.is_ignoring_damage(true), "(setup) the first ally is ignoring damage")
	a_hp = a1.health.hp
	a2_hp = a2.health.hp
	s_hp = s.health.hp
	_hit_skill(m, foe, [a1, a2], [[a1, 30], [a2, 30]])
	_check(a_hp - a1.health.hp == 0, "skipped: the damage-ignoring ally took nothing (took %d)" % (a_hp - a1.health.hp))
	_check(s_hp - s.health.hp == 20, "skipped: the whole 20 went to Stark, none stranded (took %d)" % (s_hp - s.health.hp))
	_check(a2_hp - a2.health.hp == 10,
		"skipped: the only ally actually hit drew the FULL pool (took %d, want 10)" % (a2_hp - a2.health.hp))
	for e in a1.effects.get_effects_by_type(EffectType.Type.IGNORE_DAMAGE):
		e.end_effect()

	# An Invulnerable Stark cannot cover anyone — the damage stays put rather than vanishing.
	_pass_turn(m)
	_revive(p1)
	_to_stark_turn(m)
	_cast(m, s, 3, [s])
	_check(s.is_invuln(null), "Tumble made Stark Invulnerable")
	a_hp = a1.health.hp
	s_hp = s.health.hp
	_hit(m, foe, a1, 30)
	_check(a_hp - a1.health.hp == 30, "with Stark untouchable the ally took the full 30 (took %d)" % (a_hp - a1.health.hp))
	_check(s.health.hp == s_hp, "...and nothing reached Stark")
	for e in s.effects.get_effects_by_type(EffectType.Type.INVULN):
		e.end_effect()

	# ---- Cowardice: passive off, reverse redirect, regen ----
	_pass_turn(m)
	_revive(p1)
	_to_stark_turn(m)
	_cast(m, s, 2, [s])
	_check(s.marked_by("Cowardice", s) != null, "Cowardice is active")
	_check(s.moveset.base_abilities[4].suppressed(s), "...and the passive reads as suppressed")
	a_hp = a1.health.hp
	s_hp = s.health.hp
	_hit(m, foe, a1, 30)
	_check(a_hp - a1.health.hp == 30, "the passive no longer covers allies (ally took %d)" % (a_hp - a1.health.hp))
	_check(s.health.hp == s_hp, "...and Stark absorbed nothing")

	# Now damage HIM: up to 20 splits evenly across the two living allies.
	_revive(p1)
	s_hp = s.health.hp
	a_hp = a1.health.hp
	a2_hp = a2.health.hp
	_hit(m, foe, s, 30)
	_check(s_hp - s.health.hp == 10, "Stark took 30-20 = 10 (took %d)" % (s_hp - s.health.hp))
	_check(a_hp - a1.health.hp == 10 and a2_hp - a2.health.hp == 10,
		"20 split evenly across both allies (%d / %d)" % [a_hp - a1.health.hp, a2_hp - a2.health.hp])

	# Regeneration ticks once per round on his own turn. It is a TICKING_TRIGGER, so the turn's
	# ticking batch has to be dispatched -- end_of_turn_effect_handling alone never runs them.
	_revive(p1)
	s.health.hp = 50
	_turn(m)
	_turn(m)
	_check(s.health.hp > 50, "Cowardice healed him (%d)" % s.health.hp)

	# ---- the Axe Smash slot contest ----
	for e in s.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		e.end_effect()
	_revive(p2)
	var ctx = QueryContext.from_game_state(s, m)
	s.stark_evaluate_swaps(ctx)
	_check(_slot(s, 1) == "Axe Smash", "with a healthy, unstunned enemy team the slot is Axe Smash (%s)" % _slot(s, 1))

	foe.health.hp = 30
	s.stark_evaluate_swaps(ctx)
	_check(_slot(s, 1) == "Cleaving Light", "an enemy at 30 HP summons Cleaving Light (%s)" % _slot(s, 1))

	# Boundary: an enemy just ABOVE the new threshold must NOT summon it (proves the 35 -> 30 drop).
	foe.health.hp = 33
	s.stark_evaluate_swaps(ctx)
	_check(_slot(s, 1) == "Axe Smash", "an enemy at 33 HP (>30) no longer summons Cleaving Light — threshold dropped to 30 (%s)" % _slot(s, 1))
	foe.health.hp = 30
	s.stark_evaluate_swaps(ctx)

	# Lightning Strike WINS when both conditions hold (owner ruling).
	var stun = Effect.stun_effect(4)
	stun.set_source(s.moveset.base_abilities[6])
	Character.add_hostile_effect(ctx, s, foe2, stun)
	_check(foe2.is_stunned(s.moveset.base_abilities[1]), "an enemy is Stunned")
	s.stark_evaluate_swaps(ctx)
	_check(_slot(s, 1) == "Lightning Strike", "Lightning Strike takes priority over Cleaving Light (%s)" % _slot(s, 1))
	_check(s.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP).size() == 1,
		"exactly ONE swap effect is live (got %d)" % s.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP).size())

	# Conditions lapse -> back to Axe Smash.
	for e in foe2.effects.get_effects_by_type(EffectType.Type.STUN):
		e.end_effect()
	_revive(p2)
	s.stark_evaluate_swaps(ctx)
	_check(_slot(s, 1) == "Axe Smash", "both conditions gone, slot reverts to Axe Smash (%s)" % _slot(s, 1))

	# ---- Cleaving Light ----
	foe.health.hp = 30
	s.stark_evaluate_swaps(ctx)
	_cast(m, s, 5, [foe])
	_check(foe.dead, "Cleaving Light executed an enemy at 30 HP")
	_revive(p2)
	var hp0 = foe.health.hp
	_cast(m, s, 5, [foe])
	_check(hp0 - foe.health.hp == 30 and not foe.dead, "...and deals a flat 30 to a healthy one (dealt %d)" % (hp0 - foe.health.hp))

	# ---- Lightning Strike ----
	_revive(p2)
	for e in foe.effects.get_effects_by_type(EffectType.Type.STUN):
		e.end_effect()
	hp0 = foe.health.hp
	_cast(m, s, 6, [foe])
	_check(foe.is_stunned(s.moveset.base_abilities[1]), "Lightning Strike stunned an unstunned enemy")
	_check(foe.health.hp == hp0, "...and dealt no damage doing it")
	hp0 = foe.health.hp
	_cast(m, s, 6, [foe])
	_check(hp0 - foe.health.hp == 30, "against an already-Stunned enemy it deals 30 instead (dealt %d)" % (hp0 - foe.health.hp))

	# ---- To The Rescue ----
	_revive(p1)
	_revive(p2)
	_to_stark_turn(m)
	s.moveset.base_abilities[3].cooldown_remaining = 3
	_cast(m, s, 0, [a1])
	_check(s.is_immortal(), "To The Rescue made Stark Immortal")
	var guards := 0
	for e in a1.effects.get_effects_by_type(EffectType.Type.REFLECT_RECEIVE):
		if e.user == s:
			guards += 1
	_check(guards == 1, "the guard was planted on the ally (got %d)" % guards)
	# Drive a real Harmful skill at the guarded ally and confirm the re-aim + the cooldown reset.
	var enemy_skill = foe.moveset.base_abilities[0]
	foe.used_ability = enemy_skill
	foe.targeter.targets = [a1]
	foe.targeter.main_target = a1
	var reflected: bool = foe.reflect_check(m, enemy_skill)
	_check(reflected, "the guard fired on a Harmful skill aimed at the ally")
	_check(s in foe.targeter.targets and not a1 in foe.targeter.targets,
		"the skill was re-aimed onto Stark (targets now %s)" % [foe.targeter.targets.size()])
	_check(s.moveset.base_abilities[3].cooldown_remaining == 0, "Tumble's cooldown was reset")

	# =====================================================================================
	# Regressions for the defects the adversarial review confirmed.
	# =====================================================================================

	# (1) Tumble must only be refunded when a redirect ACTUALLY happened. reflect_trigger returns
	# without re-aiming for any non-SINGLE-target skill, so a multi-target Harmful skill that merely
	# clips the guarded ally used to refund it while the ally still ate the skill.
	_revive(p1)
	_revive(p2)
	_to_stark_turn(m)
	for e in a1.effects.get_effects_by_type(EffectType.Type.REFLECT_RECEIVE):
		e.end_effect()
	_cast(m, s, 0, [a1])
	s.moveset.base_abilities[3].cooldown_remaining = 3
	# Find a genuinely multi-target Harmful skill on the enemy side.
	var aoe = null
	for c in p2.team.characters:
		for ab in c.moveset.base_abilities:
			if ab != null and ab.classes["Harmful"] and ab.target_type() == TargetType.Type.ALL:
				aoe = ab
				break
		if aoe != null:
			break
	if aoe != null:
		var caster = aoe.user
		caster.used_ability = aoe
		caster.targeter.targets = [a1, a2]
		caster.targeter.main_target = a1
		caster.reflect_check(m, aoe)
		_check(s.moveset.base_abilities[3].cooldown_remaining == 3,
			"a multi-target skill does NOT refund Tumble (cd %d, expect 3)" % s.moveset.base_abilities[3].cooldown_remaining)
	else:
		print("  ....  no multi-target Harmful skill on the enemy team; sub-check skipped")
	# ...but a single-target one still does.
	var single = foe.moveset.base_abilities[0]
	foe.used_ability = single
	foe.targeter.targets = [a1]
	foe.targeter.main_target = a1
	foe.reflect_check(m, single)
	_check(s.moveset.base_abilities[3].cooldown_remaining == 0, "a single-target redirect still refunds Tumble")

	# (2) Every piece of permanent machinery must survive Stark's death and a revive. The death
	# cleanse keeps a dying character's own effects only when system AND remove_on_death=false.
	# Clear the state the earlier phases left on him: To The Rescue makes him Immortal (which makes
	# die() a no-op) and Cowardice would suppress the passive we are about to measure.
	for e in s.effects.get_effects_by_type(EffectType.Type.IMMORTALITY):
		e.end_effect()
	for e in s.effects.get_effects_by_type(EffectType.Type.MARK):
		if e.effect_name() == "Cowardice":
			e.end_effect()
	for e in s.effects.get_effects_by_type(EffectType.Type.INVULN):
		e.end_effect()
	_check(not s.is_immortal(), "immortality cleared for the death test")
	var brands_before := 0
	for ally in [a1, a2]:
		for e in ally.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT):
			if e.user == s:
				brands_before += 1
	var tickers_before: int = s.effects.get_effects_by_type(EffectType.Type.START_OF_TURN_TRIGGER).size()
	var dealt_before: int = s.effects.get_effects_by_type(EffectType.Type.DAMAGE_DEALT_TRIGGER).size()
	_check(brands_before == 2 and tickers_before >= 1 and dealt_before >= 1,
		"baseline machinery present (brands %d, start-of-turn %d, damage-dealt %d)" % [brands_before, tickers_before, dealt_before])
	s.die(foe, null)
	_check(s.dead, "Stark died")
	var brands_after := 0
	for ally in [a1, a2]:
		for e in ally.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT):
			if e.user == s:
				brands_after += 1
	_check(brands_after == 2, "the ally brands SURVIVED his death (got %d)" % brands_after)
	_check(s.effects.get_effects_by_type(EffectType.Type.START_OF_TURN_TRIGGER).size() >= 1,
		"the refill ticker survived")
	_check(s.effects.get_effects_by_type(EffectType.Type.DAMAGE_DEALT_TRIGGER).size() >= 1,
		"the swap re-evaluation trigger survived")
	# Revive him and confirm the passive actually works again.
	s.dead = false
	s.health.hp = s.health.max_hp
	_revive(p1)
	_pass_turn(m)   # the refill ticker runs here -- which is exactly what must have survived
	_revive(p1)
	var a_hp2 = a1.health.hp
	var s_hp2 = s.health.hp
	_hit(m, foe, a1, 30)
	_check(a_hp2 - a1.health.hp == 10 and s_hp2 - s.health.hp == 20,
		"a revived Stark still absorbs 20 (ally %d / Stark %d)" % [a_hp2 - a1.health.hp, s_hp2 - s.health.hp])

	# (3) Cowardice's regen must be ALIGNED with the rest of the skill, not merely add up to 30.
	# A START_OF_TURN trigger applied during Stark's own turn has already missed that turn, so the
	# heal has to be dealt by hand at cast; otherwise it runs at offsets +2/+4/+6 while the mark and
	# the reverse redirect run +0..+5 — the last heal landing on a turn Cowardice is already over.
	# Sample the offsets one boundary at a time rather than counting, which is what hid this before.
	_revive(p1)
	_to_stark_turn(m)
	for e in s.effects.get_effects_by_type(EffectType.Type.MARK):
		if e.effect_name() == "Cowardice":
			e.end_effect()
	for e in s.effects.get_effects_by_type(EffectType.Type.START_OF_TURN_TRIGGER):
		if e.effect_name() == "Cowardice":
			e.end_effect()
	s.health.hp = 10
	var hp_at_cast: int = s.health.hp
	# Cast INSIDE a properly-modelled turn, so the volley cannot be picked up by its own cast turn's
	# ticking batch -- which is exactly the trap the manual first heal exists to cover.
	_turn(m, func (): _cast(m, s, 2, [s]))
	_check(s.health.hp - hp_at_cast == 10,
		"Cowardice heals 10 on the CAST turn (healed %d)" % (s.health.hp - hp_at_cast))
	var offsets: Array = []
	var mark_alive: Array = []
	for i in range(8):
		var before_hp: int = s.health.hp
		_turn(m)
		if s.health.hp > before_hp:
			offsets.append(i + 1)
		if s.marked_by("Cowardice", s) != null:
			mark_alive.append(i + 1)
	print("       heal boundaries after cast: %s | mark alive through: %s" % [offsets, mark_alive])
	_check(offsets.size() == 2, "exactly two further heals after the cast turn (got %d)" % offsets.size())
	# Every heal must land while Cowardice is still running.
	var stragglers := 0
	for o in offsets:
		if not o in mark_alive:
			stragglers += 1
	_check(stragglers == 0, "no heal lands after Cowardice has expired (%d straggler(s))" % stragglers)
	_check(s.health.hp == 40, "30 HP healed in total across the window (hp %d, from 10)" % s.health.hp)

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
