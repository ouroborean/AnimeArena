extends Ability

# Owl Finisher (hidden, base_abilities[6]). The SSS Ukaku Quinque passive swaps it over Ixa Parry while
# any character on the field is at <=15 HP. Executes a target enemy OR a non-self ally at <=15 HP;
# executing an ally grants Arima 2 Red energy. instant_kill respects Embrace Pain / Sealed Nightmare /
# immortality, so the energy is guarded on an actual death.

func describe(user):
	return "Executes target enemy or other allied character at 15 or less HP. If this executes an ally, Arima gains 2 Red energy."

func split_desc():
	return [
		"Executes target enemy or other allied character at 15 or less HP",
		["If it executes an ally, Arima gains 2 Red energy", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target == user:
			continue
		var was_ally = not user.is_hostile(target)
		target.instant_kill(user, self)
		if was_ally and target.dead:
			user.gain_bonus_energy(Energy.Type.RED)
			user.gain_bonus_energy(Energy.Type.RED)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 1000)   # execute weight (mirrors hisoka6)
	return variations

func target(user, battle):
	# Selectable set = every enemy OR non-self ally currently at <=15 HP.
	var context = QueryContext.from_game_state(user, battle)
	for c in battle.all_characters():
		if c == user or c.dead or c.banished:
			continue
		if c.health.hp <= 15:
			if user.is_hostile(c):
				check_hostile_target(user, c, context)
			else:
				check_allied_target(user, c, context)
