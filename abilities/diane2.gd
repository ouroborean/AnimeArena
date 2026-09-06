extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Diane gains 30 Shield. While the Shield holds, Mother Catastrophe will take 1 more turn to activate and deal 20 more damage. If used while Mother Catastrophe is active, this will extend and boost the active instance."

func split_desc():
	return [
		"Diane gains 30 Shield",
		["Mother Catastrophe will wait 1 more turn and deals +20 damage", Color.CADET_BLUE],
		"If used while Mother Catastrophe is waiting, this effect applies to that Mother Catastrophe"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shield = Effect.shield_effect(30, -1)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	if user.has_effect("Mother Catastrophe", EffectType.Type.TICKING_TRIGGER, user):
		user.has_effect("Mother Catastrophe", EffectType.Type.TICKING_TRIGGER, user).duration += 2
		user.has_effect("Mother Catastrophe", EffectType.Type.TICKING_TRIGGER, user).mag += 20
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	var mod = 0
	if user.has_effect("Mother Catastrophe", EffectType.Type.TICKING_TRIGGER, user):
		mod += 75
	variations += behavior_self_panic_button(context, 25 + mod, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
