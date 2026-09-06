extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy and 5 Piercing damage to their allies",
		["Repeats once for each stack of Thunder Antenna on Jupiter", Color.CADET_BLUE],
		["Requires 3+ stacks of Thunder Antenna and consumes all stacks on use", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var antenna
	if user.has_effect("Thunder Antenna", EffectType.Type.DAMAGE_MOD):
		antenna = user.has_effect("Thunder Antenna", EffectType.Type.DAMAGE_MOD)
	else:
		return
	for target in user.targeter.targets:
		var damage = 5
		if target == user.targeter.main_target:
			damage = 15
		for i in range(antenna.stacks):
			Character.resolve_damage(context, target, damage, DamageType.Type.PIERCING)
	user.effects.erase_effect(antenna)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Thunder Antenna", EffectType.Type.DAMAGE_MOD) and user.has_effect("Thunder Antenna", EffectType.Type.DAMAGE_MOD).stacks >= 3
	
func custom_behavior(context):
	var variations = []
	
	if not (user.has_effect("Thunder Antenna", EffectType.Type.DAMAGE_MOD) and user.has_effect("Thunder Antenna", EffectType.Type.DAMAGE_MOD).stacks >= 3):
		variations.append([0, [user, "PASS", []]])
	else:
		variations += behavior_hostile_splash_aoe(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
