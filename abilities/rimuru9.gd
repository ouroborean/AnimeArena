extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Rimuru removes all enemy skills from himself, then heals his entire team 20HP, and then himself 5HP permanently. Swaps all skills but 'Slime Transformation' to alternates."

func split_desc():
	return [
		"Removes all enemy effects from Rimuru",
		"Heals his entire team 20 HP",
		["Rimuru permanently heals 5 HP each turn", Color.CADET_BLUE],
		["Swaps all skills except Slime Transformation to their alternates", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	user.effects.cleanse_all_enemy_effects(user)
	var portrait = Effect.portrait_change_effect(0, -1)
	portrait.set_source(self)
	Character.add_allied_effect(context, user, user, portrait)
	for target in user.targeter.targets:
		if target in user.team.characters:
			Character.resolve_healing(context, target, 20)
	
	Character.resolve_healing(context, user, 5)
	var heal_eff = Effect.healing_effect(5, -1)
	heal_eff.set_source(self)
	heal_eff.cleansable = false
	Character.add_allied_effect(context, user, user, heal_eff)
	
	var swap1 = Effect.ability_swap_effect(4, 0, user, -1)
	swap1.set_source(self)
	swap1.cleansable = false
	var swap2 = Effect.ability_swap_effect(5, 1, user, -1)
	swap2.set_source(self)
	swap2.cleansable = false
	var swap3 = Effect.ability_swap_effect(6, 2, user, -1)
	swap3.set_source(self)
	swap3.cleansable = false
	Character.add_allied_effect(context, user, user, swap1)
	Character.add_allied_effect(context, user, user, swap2)
	Character.add_allied_effect(context, user, user, swap3)
	
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return false
	
func target(user, battle):
	pass
