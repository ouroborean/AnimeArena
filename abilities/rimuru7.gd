extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Targets an enemy or an ally. If an ally, removes all Affliction skills from them and heals 15HP. If an enemy, Shatters them and reduces their damage by 15 for 1 turn."

func split_desc():
	return [
		["If used on an ally, removes all Affliction effects from them and heals 15 HP", Color.CADET_BLUE],
		["If used on an enemy, Shatters them and reduces their damage by 15 for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			target.effects.cleanse_hostile_afflictions(target)
			Character.resolve_healing(context, target, 15)
		else:
			var shatter = Effect.def_negate(3)
			shatter.set_source(self)
			var weakness = Effect.damage_mod_effect(-15, 2)
			weakness.set_source(self)
			Character.add_hostile_effect(context, user, target, shatter)
			Character.add_hostile_effect(context, user, target, weakness)
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Slime Transformation", EffectType.Type.IGNORE_NON_DAMAGE, user) == null
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_any_target(context, 20)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
