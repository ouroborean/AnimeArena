extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "King becomes invulnerable for 1 turn."

func split_desc():
	return [
		"Target ally gains 20 Shield for 1 turn",
		["Reflects the next Harmful skill target ally receives for 1 turn while Empowered (Invisible)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if user.marked_by("True Spirit Spear Chastifold"):
			var reflect = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE, -1, 2, "King reflects the next Harmful skill used on this ally.", ["Harmful"], [], 1)
			reflect.set_source(self)
			reflect.invisible = true
			Character.add_allied_effect(context, user, target, reflect)
		else:
			var shield = Effect.shield_effect(20, 2)
			shield.set_source(self)
			Character.add_allied_effect(context, user, target, shield)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 15)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
