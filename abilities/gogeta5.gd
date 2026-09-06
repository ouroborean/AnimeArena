extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The enemy currently being targeted by Big Bang Kamehameha is stunned for 1 turn and Gogeta's skills cost 1 less Random energy for 3 turns. Using this skill will cancel Big Bang Kamehameha, and it will fail if Big Bang Kamehameha has already occurred this turn. Uncounterable."

func split_desc():
	return [
		"Stuns the target of Big Bang Kamehameha and lowers Gogeta's skill costs by 1 Random for 3 turns",
		"Cancels Big Bang Kamehameha, or fails if it has already activated"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(2)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
	var cost_mod = Effect.cost_mod_effect(-1, 7, Energy.Type.RANDOM)
	cost_mod.set_source(self)
	Character.add_allied_effect(context, user, user, cost_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, -10)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if character.has_effect("Big Bang Kamehameha", EffectType.Type.TICKING_TRIGGER, user):
			check_hostile_target(user, character, context)
