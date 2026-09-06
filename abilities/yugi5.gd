extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Removes all Counter and Reflect effects from all enemies, then deals 25 damage to them",
		["Usable while Swords of Revealing Light prevents Harmful skills", Color.CADET_BLUE],
		["Using this skill will end Swords of Revealing Light", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var count = 0
	for target in user.targeter.targets:
		for effect in target.effects.get_effects_by_type(EffectType.Type.COUNTER_USE):
			count += 1
			target.effects.erase_effect(effect)
		for effect in target.effects.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE):
			count += 1
			target.effects.erase_effect(effect)
		Character.resolve_damage(context, target, 25, DamageType.Type.NORMAL)
	user.manually_advance_mission(6, count)
	# Swords is a non-ignorable STUN now (not a skill_seal) - probe STUN, or Dark Magician can never end
	# Swords.
	if user.has_effect("Swords of Revealing Light", EffectType.Type.STUN, user):
		for character in battle.all_characters():
			if character.has_effect("Swords of Revealing Light", EffectType.Type.STUN, user):
				character.effects.full_remove_effect_by_name("Swords of Revealing Light", user)
	user.call_unique("yugi", "check_card", ["magician"])
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 35)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
