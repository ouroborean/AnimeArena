extends Ability

# Vital Strike (default form). Deals 15 damage; the turn after a PAID cast, the next cast is free.
# execute() leaves a self-MARK that cost() reads to zero the cost; the free cast consumes the mark so
# it never chains into permanently-free casts.

func describe(user):
	return "Deals 15 damage to target enemy. The following turn, this skill costs no energy."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["Costs no energy the following turn", Color.DIM_GRAY],
	]

func cost():
	var output = super.cost()
	if user == null:
		return output
	if user.has_effect("Vital Strike", EffectType.Type.MARK, user):
		output = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	return output

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
	if user.has_effect("Vital Strike", EffectType.Type.MARK, user):
		# This was the discounted cast — consume the mark instead of refreshing it.
		user.effects.remove_effect("Vital Strike", EffectType.Type.MARK, user)
	else:
		var mark = Effect.mark(3, "This skill costs no energy next turn.")
		mark.set_source(self)
		Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 15)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
