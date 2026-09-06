extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Noelle ignores all harmful effects until the end of her next turn. For 1 turn, Sea Dragon's Roar will target all enemies and this move is replaced by Point-Blank Sea Dragon's Roar."

func split_desc():
	return [
		"Noelle ignores all Harmful effects until the end of her next turn",
		["For 1 turn, Sea Dragon's Roar targets all enemies", Color.CADET_BLUE],
		["Replaced by Point-Blank Sea Dragon's Roar", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var harmful_ignore = Effect.ignore_non_damage_effect(3)
	harmful_ignore.set_source(self)
	var damage_ignore = Effect.ignore_damage_effect(3)
	damage_ignore.set_source(self)
	Character.add_allied_effect(context, user, user, harmful_ignore)
	Character.add_allied_effect(context, user, user, damage_ignore)
	
	var target_change = Effect.target_change_effect(TargetType.Type.ALL, 5, ["Sea Dragon's Roar"])
	target_change.set_source(self)
	var ability_swap = Effect.ability_swap_effect(5, 2, user, 3)
	ability_swap.set_source(self)
	Character.add_allied_effect(context, user, user, target_change)
	Character.add_allied_effect(context, user, user, ability_swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
