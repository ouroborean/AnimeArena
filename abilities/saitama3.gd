extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Saitama removes all harmful skills from his team. For 1 turn, Saitama's team becomes Invulnerable and for 2 turns the enemy team becomes Shattered. Swaps to 'Serious Series: Omni-Directional Serious Punch' permanently."

func split_desc():
	return [
		"Cleanses Saitama's team of enemy effects and makes them Invulnerable for 1 turn",
		"Shatters the enemy team for 2 turns"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hostile = Condition.is_hostile(user, target)
		if hostile.satisfied(context):
			var shatter_eff = Effect.def_negate(3)
			shatter_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, shatter_eff, true)
		else:
			target.effects.cleanse_all_enemy_effects(target)
			var invuln_eff = Effect.invuln_effect(2)
			invuln_eff.set_source(self)
			Character.add_allied_effect(context, user, target, invuln_eff, true)

	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 15, true)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
	default_allied_target_function(user, battle, true)
