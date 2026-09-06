extends Ability

func describe(user):
	return "If Jesse has at least 1 stack of Crystal Beasts, deals 10 damage to all enemies. If he has at least 3, deals double damage. If he has at least 5, stuns its targets' Harmful skills for 1 turn. If he has at least 7, deals triple damage."

func split_desc():
	return [
		"If Jesse has at least 1 stack of Crystal Beasts, deals 10 damage to all enemies.",
		["If he has at least 3, deals double damage.", Color.DIM_GRAY],
		["If he has at least 5, stuns its targets' Harmful skills for 1 turn.", Color.CADET_BLUE],
		["If he has at least 7, deals triple damage.", Color.AQUA],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	var stacks = 0
	if cb_eff:
		stacks = cb_eff.stacks

	# Determine damage based on stack thresholds
	var damage = 0
	if stacks >= 7:
		damage = 30
	elif stacks >= 3:
		damage = 20
	elif stacks >= 1:
		damage = 10

	for target in user.targeter.targets:
		if damage > 0:
			Character.resolve_damage(context, target, damage, DamageType.Type.NORMAL)

		# At 5+ stacks, stun Harmful skills for 1 turn
		if stacks >= 5:
			var stun = Effect.stun_effect(2, ["Harmful"])
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	return cb_eff != null and cb_eff.stacks >= 1

func custom_behavior(context):
	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	var stacks = 0
	if cb_eff:
		stacks = cb_eff.stacks

	var damage = 0
	if stacks >= 7:
		damage = 30
	elif stacks >= 3:
		damage = 20
	elif stacks >= 1:
		damage = 10

	var bonus = 0
	if stacks >= 5:
		bonus = 15

	return behavior_hostile_aoe_damage(context, damage + bonus, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
