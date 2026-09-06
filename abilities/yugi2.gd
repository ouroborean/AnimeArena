extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 25 damage to target enemy",
		["Usable while Swords of Revealing Light prevents Harmful skills", Color.CADET_BLUE],
		["Using this skill will end Swords of Revealing Light", Color.DIM_GRAY],
		["If this ends Swords of Revealing Light, this skill swaps to Dark Magician for 2 turns", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 25, DamageType.Type.NORMAL)
	# Swords is a non-ignorable STUN now (not a skill_seal) - probe STUN, or the whole "ends Swords +
	# swaps to Dark Magician" branch silently dies.
	if user.has_effect("Swords of Revealing Light", EffectType.Type.STUN, user):
		for character in battle.all_characters():
			if character.has_effect("Swords of Revealing Light", EffectType.Type.STUN, user):
				character.effects.full_remove_effect_by_name("Swords of Revealing Light", user)
		var swap = Effect.ability_swap_effect(4, 1, user, 5)
		swap.set_source(self)
		Character.add_allied_effect(context, user, user, swap)
	user.call_unique("yugi", "check_card", ["girl"])
		
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
