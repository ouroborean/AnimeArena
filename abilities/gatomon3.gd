extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Gatomon digivolves based on her Digivolution stacks, replacing her skills for the rest of the game. If used with 2 stacks of Digivolution, Gatomon will digivolve into Angewomon. If used with 3 stacks, Gatomon will digivolve into Ophanimon. This skill is usable while stunned."

func split_desc():
	return [
		"Gatomon permanently changes form based on her Digivolution stacks:",
		["1 Stack: Angewomon", Color.AQUAMARINE],
		["2 Stacks: Ophanimon", Color.AQUAMARINE],
		
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var digivolve = user.has_effect("Gatomon Digivolve", EffectType.Type.MARK, user).stack_count()
	if digivolve >= 2:
		var switch1 = Effect.ability_swap_effect(9, 0, user, -1)
		switch1.set_source(self)
		var switch2 = Effect.ability_swap_effect(10, 1, user, -1)
		switch2.set_source(self)
		var switch3 = Effect.ability_swap_effect(11, 2, user, -1)
		switch3.set_source(self)
		var switch4 = Effect.ability_swap_effect(12, 3, user, -1)
		switch4.set_source(self)
		
		var healing_eff = Effect.healing_effect(10, -1)
		healing_eff.set_source(user.moveset.base_abilities[13])
		var portrait_change = Effect.portrait_change_effect(1, -1)
		portrait_change.set_source(self)
		
		Character.add_allied_effect(context, user, user, portrait_change)
		Character.add_allied_effect(context, user, user, switch1)
		Character.add_allied_effect(context, user, user, switch2)
		Character.add_allied_effect(context, user, user, switch3)
		Character.add_allied_effect(context, user, user, switch4)
		Character.add_allied_effect(context, user, user, healing_eff)
		
	else:
		var switch1 = Effect.ability_swap_effect(4, 0, user, -1)
		switch1.set_source(self)
		var switch2 = Effect.ability_swap_effect(5, 1, user, -1)
		switch2.set_source(self)
		var switch3 = Effect.ability_swap_effect(6, 2, user, -1)
		switch3.set_source(self)
		var switch4 = Effect.ability_swap_effect(7, 3, user, -1)
		switch4.set_source(self)
		
		
		var healing_eff = Effect.healing_effect(5, -1)
		healing_eff.set_source(user.moveset.base_abilities[8])
		var portrait_change = Effect.portrait_change_effect(0, -1)
		portrait_change.set_source(self)
		
		Character.add_allied_effect(context, user, user, portrait_change)
		Character.add_allied_effect(context, user, user, switch1)
		Character.add_allied_effect(context, user, user, switch2)
		Character.add_allied_effect(context, user, user, switch3)
		Character.add_allied_effect(context, user, user, switch4)
		Character.add_allied_effect(context, user, user, healing_eff)
		
	user.effects.remove_effect("Gatomon Digivolve", EffectType.Type.MARK, user)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Gatomon Digivolve", user) and user.has_effect("Gatomon Digivolve", EffectType.Type.MARK, user).stack_count() >= 1
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 150, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
