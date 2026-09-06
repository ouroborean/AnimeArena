extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Misaka makes her team invulnerable for 1 turn. For the rest of the game, Iron Sand and Railgun affect all valid targets. Using this ability will reset all her abilities to their original forms and prevent her from switching for the rest of the game."

func split_desc():
	return [
		"Misaka's team becomes invulnerable for 1 turn",
		["For the rest of the game, Iron Sand and Railgun affect all valid targets", Color.CADET_BLUE],
		["Resets all her abilities to their original forms and locks switching for the rest of the game", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var invuln = Effect.invuln_effect(2)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, target, invuln)
	
	for swap in user.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		if swap.user == user:
			user.effects.erase_effect(swap)
	
	var lockout_mark = Effect.mark(-1, "Iron Sand and Railgun cannot swap to their alternate effects.")
	lockout_mark.set_source(self)
	var target_change_railgun = Effect.target_change_effect(TargetType.Type.ALL, -1, ["Railgun", "Iron Sand", "Overcharge"])
	target_change_railgun.set_source(self)
	Character.add_allied_effect(context, user, user, lockout_mark)
	Character.add_allied_effect(context, user, user, target_change_railgun)
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_helpful_aoe_aid(context, 75, 1.2)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
