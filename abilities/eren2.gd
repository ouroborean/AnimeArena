extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Eren targets another ally, reflecting all harmful skills used on them to himself for 2 turns. This skill is invisible."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var eff = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE, user, 4, "Harmful skills will be reflected to Eren.", ["Harmful"])
		eff.set_source(self)
		eff.invisible = true
		Character.add_allied_effect(context, user, target, eff)

func split_desc():
	return [
		"Reflects all Harmful skills used on another ally to Eren for 2 turns (Invisible)",
		"Swaps to Titan KO during Titan Transformation"
	]

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_selfless_helpful(context, 80, 1.2)
	
	return variations
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
