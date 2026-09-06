extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tamaki gains 15 permanent Shield and for the next 3 turns, she will ignore negative non-damage effects and Nekomata Cage will target all enemies. This skill becomes Nekomata Fireball while active."

func split_desc():
	return [
		["Tamaki gains 15 permanent Shield", Color.CADET_BLUE],
		["Ignores negative non-damage effects for 3 turns", Color.CADET_BLUE],
		["Nekomata Cage targets all enemies for 3 turns", Color.CADET_BLUE],
		["Swaps with Nekomata Fireball", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var non_damage_ign = Effect.ignore_non_damage_effect(7)
	non_damage_ign.set_source(self)
	var target_change = Effect.target_change_effect(TargetType.Type.ALL, 7, ["Nekomata Cage"])
	target_change.set_source(self)
	var shield = Effect.shield_effect(15, -1)
	shield.set_source(self)
	var swap = Effect.ability_swap_effect(4, 2, user, 7)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	Character.add_allied_effect(context, user, user, swap)
	Character.add_allied_effect(context, user, user, target_change)
	Character.add_allied_effect(context, user, user, non_damage_ign)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 150)
	
	return variations
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
