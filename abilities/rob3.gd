extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to target enemy. If the targeted enemy has Shield, this skill deals Affliction damage instead. Swaps with Sai Dai Rin: Rokuogan on use."

func split_desc():
	return [
		"Deals 30 damage to target enemy",
		["Deals Affliction damage instead if the target has Shield", Color.CADET_BLUE],
		["Swaps with Sai Dai Rin: Rokuogan on use", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var damage_type = DamageType.Type.NORMAL
		var shields = target.get_effects_by_type(EffectType.Type.SHIELD)
		if shields:
			damage_type = DamageType.Type.AFFLICTION
			user.manually_advance_mission(10, 1)
		Character.resolve_damage(context, target, 30, damage_type)
	
	
	var swap = Effect.ability_swap_effect(6, 2, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 40)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
