extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Removes all active counter effects",
		["Inosuke deals +5 Piercing damage next turn, increased by 5 for each counter removed", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var count = 1
	for target in user.targeter.targets:
		for effect in target.effects.get_effects_by_type(EffectType.Type.COUNTER_USE):
			count += 1
			target.effects.erase_effect(effect)
		for effect in target.effects.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE):
			count += 1
			target.effects.erase_effect(effect)
	user.manually_advance_mission(9, count)
	for i in range(count):
		var damage_mod = Effect.damage_mod_effect(5, 3, [], [], [], [DamageType.Type.PIERCING])
		damage_mod.set_source(self)
		damage_mod.stackable = true
		damage_mod.stack_mag = true
		damage_mod.display_stacks = true
		Character.add_allied_effect(context, user, user, damage_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 10)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
