extends Ability

var base_damage = 15

func describe(user):
	return "Deals 15 damage to target enemy each turn and increases the cost of their skills by 1 Random energy. Lasts 1 more turn for each random energy this skill costs."

func split_desc():
	return [
		"Deals 15 damage to target enemy each turn",
		"Their skills cost 1 more Random energy for 1 turn",
		["Lasts 1 more turn for each random energy this skill costs", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var bonus_turns = cost()[Energy.Type.RANDOM]
	var dur = 2 + (2 * bonus_turns)
	for target in user.targeter.targets:
		# instance 1 on the cast turn, then a DoT covering the SAME cost-scaled window as the tax
		# (dur-1 = 2N-1 for N = 1 + bonus_turns total hits; at bonus_turns=0 that is a single hit)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var dot = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, dur - 1)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)
		var tax = Effect.cost_mod_effect(1, dur, Energy.Type.RANDOM)
		tax.set_source(self)
		Character.add_hostile_effect(context, user, target, tax)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
