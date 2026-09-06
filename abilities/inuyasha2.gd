extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 Affliction damage to target enemy. This effect repeats for each time Inuyasha has received damage since the last time this skill was used (max 3).",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var count = 1
	if user.has_effect("Blades of Blood", EffectType.Type.DAMAGE_RECEIVE_TRIGGER):
		count += user.has_effect("Blades of Blood", EffectType.Type.DAMAGE_RECEIVE_TRIGGER).mag
	var base_damage = 10
	if user.has_effect("Hanyo Cycle", EffectType.Type.MARK):
		match user.has_effect("Hanyo Cycle", EffectType.Type.MARK).mag:
			0:
				pass
			1:
				base_damage = 15
			2:
				base_damage = 5
	for target in user.targeter.targets:
		for i in range(count):
			Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
	if user.has_effect("Blades of Blood", EffectType.Type.DAMAGE_RECEIVE_TRIGGER):
		user.has_effect("Blades of Blood", EffectType.Type.DAMAGE_RECEIVE_TRIGGER).mag = 0
		
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
