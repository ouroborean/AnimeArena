extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tamaki gains 10 points of damage reduction for 1 turn, and reflects all Harmful skills used on another ally to herself."

func split_desc():
	return [
		["Tamaki gains 10 damage reduction for 1 turn", Color.CADET_BLUE],
		["Reflects all harmful skills used on another ally to Tamaki", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var eff = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE, user, 2, "Harmful skills will be reflected to Tamaki.", ["Harmful"])
		eff.set_source(self)
		eff.wrapup_func = default_counter_timeout
		eff.invisible = true
		Character.add_allied_effect(context, user, target, eff)
	var dr = Effect.damage_reduction_effect(10, 2)
	dr.set_source(self)
	dr.invisible = true
	Character.add_allied_effect(context, user, user, dr)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
