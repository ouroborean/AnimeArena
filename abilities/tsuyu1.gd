extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target enemy receives 20 damage per turn for 2 turns, or target ally gains 15 Damage Reduction for 2 turns",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			var dr = Effect.damage_reduction_effect(15, 4)
			dr.set_source(self)
			var mark = Effect.mark(4, "Tsuyu will leap with this character.")
			mark.set_source(self)
			Character.add_allied_effect(context, user, target, mark)
			Character.add_allied_effect(context, user, target, dr)
		else:
			Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
			var tick = Effect.damage_effect(20, DamageType.Type.NORMAL, 3)
			tick.set_source(self)
			var mark = Effect.mark(3, "Tsuyu will leap with this character.")
			mark.set_source(self)
			Character.add_hostile_effect(context, user, target, mark)
			Character.add_hostile_effect(context, user, target, tick)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_any_target(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
