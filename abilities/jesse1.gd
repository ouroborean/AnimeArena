extends Ability

func describe(user):
	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	var stacks = 0
	if cb_eff:
		stacks = cb_eff.stacks
	var total_damage = 20 + (5 * stacks)
	return "Deals " + str(total_damage) + " damage to target enemy and gives Jesse 2 stacks of Crystal Beasts. Deals 5 more damage for each stack of Crystal Beasts on Jesse. After, if Jesse has at least 7 stacks of Crystal Beasts, this skill is permanently replaced with Rainbow Dragon."

func split_desc():
	return [
		"Deals 20 damage to target enemy and gives Jesse 2 stacks of Crystal Beasts.",
		["Deals 5 more damage for each stack of Crystal Beasts on Jesse.", Color.DIM_GRAY],
		["After, if Jesse has at least 7 stacks of Crystal Beasts, this skill is permanently replaced with Rainbow Dragon.", Color.AQUA],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Read current stacks
	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	var stacks = 0
	if cb_eff:
		stacks = cb_eff.stacks

	# Deal scaled damage: 20 base + 5 per existing stack
	var damage = 20 + (5 * stacks)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, DamageType.Type.NORMAL)

	# Add 2 stacks of Crystal Beasts
	for i in range(2):
		var mark = Effect.mark(-1, "Crystal Beasts will deal 5 more damage per stack.")
		mark.set_source(self)
		mark.stackable = true
		mark.display_stacks = true
		Character.add_allied_effect(context, user, user, mark)

	# If >= 7 stacks after adding, permanently swap this skill with Rainbow Dragon
	cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	if cb_eff and cb_eff.stacks >= 7:
		var swap = Effect.ability_swap_effect(4, 0, user, -1)
		swap.set_source(self)
		Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var stacks = 0
	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	if cb_eff:
		stacks = cb_eff.stacks
	var damage_estimate = 20 + (5 * stacks)
	return behavior_single_target_damage(context, damage_estimate, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
