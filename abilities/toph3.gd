extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target ally gains 30 Shield and is Blinded as long as the Shield persists (refreshes)",
		["While Toph holds Metal Armor herself, her skills deal 5 more damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target.has_effect("Metal Armor", EffectType.Type.SHIELD, user):
			target.has_effect("Metal Armor", EffectType.Type.SHIELD, user).mag = 30
		else:
			var shield = Effect.shield_effect(30, -1)
			shield.set_source(self)
			Character.add_allied_effect(context, user, target, shield)
			var blind = Effect.blind_effect(-1)
			blind.set_source(self)
			Character.add_allied_effect(context, user, target, blind)
	
	
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
