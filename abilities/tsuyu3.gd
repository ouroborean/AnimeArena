extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target deals 10 less non-Affliction damage for 2 turns, or target ally ignores negative non-damage effects for 2 turns",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			var ignore = Effect.ignore_non_damage_effect(4)
			ignore.set_source(self)
			Character.add_allied_effect(context, user, target, ignore)
		else:
			var damage_mod = Effect.damage_mod_effect(-10, 4, [], [], [DamageType.Type.AFFLICTION])
			damage_mod.set_source(self)
			Character.add_hostile_effect(context, user, target, damage_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_any_target(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
