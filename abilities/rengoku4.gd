extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Removes all damage effects from Rengoku. For 1 turn he will ignore Stun effects and this skill swaps to Ninth Form: Rengoku."

func split_desc():
	return [
		"Removes all damage effects from Rengoku",
		["For 1 turn, he ignores Stun effects", Color.CADET_BLUE],
		["Swaps to Ninth Form: Rengoku", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.effects.full_remove_effect_by_type(EffectType.Type.DAMAGE)
	var stun_ignore = Effect.ignore_effect_effect(2, EffectType.Type.STUN)
	stun_ignore.set_source(self)
	Character.add_allied_effect(context, user, user, stun_ignore)
	var swap = Effect.ability_swap_effect(4, 3, user, 3)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25, 1.4)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
