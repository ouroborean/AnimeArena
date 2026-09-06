extends Ability

# Summon - Tank (White form). Jin-woo gains 30 Shield and his whole team gains 10 permanent Damage
# Reduction, then permanently swaps this slot for Grand Challenge.

func describe(user):
	return "Jin-woo gains 30 Shield and his team gains 10 permanent Damage Reduction. This skill is then replaced by Grand Challenge."

func split_desc():
	return [
		["Jin-woo gains 30 Shield", Color.CADET_BLUE],
		["Jin-woo's team gains 10 permanent Damage Reduction", Color.CADET_BLUE],
		["Replaced by Grand Challenge", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shield = Effect.shield_effect(30, -1)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	for ally in context['ally_team'].characters:
		if ally.dead or ally.banished:
			continue
		var dr = Effect.damage_reduction_effect(10, -1)
		dr.set_source(self)
		Character.add_allied_effect(context, user, ally, dr)
	var swap = Effect.ability_swap_effect(4, 2, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
