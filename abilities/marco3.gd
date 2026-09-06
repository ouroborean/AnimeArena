extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, Marco will reflect the first harmful skill used on target ally (Invisible)",
		["While on cooldown, swaps to Pineapple Stone", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var eff = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE, -1, 2, "Harmful skills will be reflected to their user.", ["Harmful"], [], 1)
		eff.set_source(self)
		eff.wrapup_func = default_counter_timeout
		eff.invisible = true
		Character.add_allied_effect(context, user, target, eff)
	var swap = Effect.ability_swap_effect(4, 2, user, 5)
	swap.set_source(self)
	swap.invisible = true
	Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 30)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
