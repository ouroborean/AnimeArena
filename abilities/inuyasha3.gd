extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Removes all allied effects from target enemy and deals 30 Piercing damage to them",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var base_damage = 30
	
	if user.has_effect("Hanyo Cycle", EffectType.Type.MARK):
		match user.has_effect("Hanyo Cycle", EffectType.Type.MARK).mag:
			0:
				pass
			1:
				base_damage = 45
			2:
				base_damage = 15
	
	for target in user.targeter.targets:
		target.effects.cleanse_all_ally_effects(target, user)   # user = breaker (attributes shield/barrier break hooks)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
