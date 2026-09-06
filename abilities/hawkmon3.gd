extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""


func split_desc():
	return [
		"Hawkmon permanently changes form based on his stacks of Hawkmon Digivolve:",
		["1 Stack: Aquilamon", Color.AQUAMARINE],
		["2 Stacks: Silphymon", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var digivolve = user.has_effect("Hawkmon Digivolve", EffectType.Type.MARK, user).stack_count()
	if digivolve >= 2:
		var switch1 = Effect.ability_swap_effect(8, 0, user, -1)
		switch1.set_source(self)
		var switch2 = Effect.ability_swap_effect(9, 1, user, -1)
		switch2.set_source(self)
		var switch3 = Effect.ability_swap_effect(10, 2, user, -1)
		switch3.set_source(self)
		var switch4 = Effect.ability_swap_effect(11, 3, user, -1)
		switch4.set_source(self)
		
		var portrait_change = Effect.portrait_change_effect(1, -1)
		portrait_change.set_source(self)
		
		Character.add_allied_effect(context, user, user, portrait_change)
		Character.add_allied_effect(context, user, user, switch1)
		Character.add_allied_effect(context, user, user, switch2)
		Character.add_allied_effect(context, user, user, switch3)
		Character.add_allied_effect(context, user, user, switch4)
		user.effects.remove_effect("Hawkmon Digivolve", EffectType.Type.MARK, user)
		var mark = Effect.mark(-1, "Silphymon is observing effects applied by his allies")
		mark.set_source(self)
		mark.mag = 999
		mark.unique_render_id = 3
		mark.cleansable = false
		Character.add_allied_effect(context, user, user, mark)
		
		
		
	else:
		var switch1 = Effect.ability_swap_effect(4, 0, user, -1)
		switch1.set_source(self)
		var switch2 = Effect.ability_swap_effect(5, 1, user, -1)
		switch2.set_source(self)
		var switch3 = Effect.ability_swap_effect(6, 2, user, -1)
		switch3.set_source(self)
		var switch4 = Effect.ability_swap_effect(7, 3, user, -1)
		switch4.set_source(self)
		
		var portrait_change = Effect.portrait_change_effect(0, -1)
		portrait_change.set_source(self)
		
		Character.add_allied_effect(context, user, user, portrait_change)
		Character.add_allied_effect(context, user, user, switch1)
		Character.add_allied_effect(context, user, user, switch2)
		Character.add_allied_effect(context, user, user, switch3)
		Character.add_allied_effect(context, user, user, switch4)
		user.effects.remove_effect("Hawkmon Digivolve", EffectType.Type.MARK, user)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Hawkmon Digivolve", user) and user.has_effect("Hawkmon Digivolve", EffectType.Type.MARK, user).stack_count() >= 1
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 150, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
