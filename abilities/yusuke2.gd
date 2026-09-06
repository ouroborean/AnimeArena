extends Ability

# Spirit Fist. One strike = 10 damage + (a dur-3 Silence, or drain 1 energy if the target is ALREADY
# Silenced by this skill). Empowered simply repeats that identical strike TWICE in a row — it does NOT
# lengthen the Silence — so on a fresh target hit 1 Silences and hit 2 (now Silenced by hit 1) drains,
# self-combining in one use. Dur 3 = the Silence lasts the turn it lands, the enemy's turn, and up to
# the end of Yusuke's next turn (so a later Spirit Fist can still proc the drain).

func describe(user):
	return "Deals 10 damage to target enemy and Silences them until the end of Yusuke's next turn, or drains 1 energy instead if they are already Silenced by this skill. While Empowered, this whole strike happens twice in a row."

func split_desc():
	return [
		"Deals 10 damage to target enemy and Silences them until the end of Yusuke's next turn",
		["Drains 1 energy instead of Silencing if the target is already Silenced by this skill", Color.CADET_BLUE],
		["While Empowered: repeats this strike twice in a row (so the first Silences and the second drains)", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.marked_by("Empowered", user)
	var hits = 2 if empowered else 1
	for target in user.targeter.targets:
		# Empowered just runs the identical single strike twice; each hit re-reads the Silence state, so
		# hit 1 Silences and hit 2 drains. The Silence is always dur 3 — Empowered does not extend it.
		for i in range(hits):
			var hp_before = target.health.hp
			Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
			var dealt = target.health.hp < hp_before
			var already = target.has_effect("Spirit Fist", EffectType.Type.SILENCE, user)
			if already != null and dealt:
				target.lose_energy(user, 1)   # drains instead of re-Silencing
			else:
				var silence = Effect.silence_effect(3)
				silence.set_source(self)
				Character.add_hostile_effect(context, user, target, silence)
	if empowered:
		user.effects.erase_effect(empowered)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 10)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
