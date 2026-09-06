extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 3 turns, Deep Forest Bloom: Pollen and Deep Forest Bloom: Strangle are enhanced and delayed for 1 more turn. While active, this skill can be reactivated to extend the duration on all active delay effects by 1 turn."

func split_desc():
	return [
		"For 3 turns, Deep Forest Bloom: Pollen and Deep Forest Bloom: Strangle are enhanced and delayed for 1 more turn",
		"While active, can be reactivated to extend all active delay effects by 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	
	if not user.marked_by("Deep Forest Creation", user):
		var mark = Effect.mark(7, "Deep Forest Bloom: Pollen and Deep Forest Bloom: Strangle are enhanced and delayed for 1 more turn.")
		mark.set_source(self)
		mark.wrapup_func = wrapup_trigger
		Character.add_allied_effect(context, user, user, mark)
	
		var delay = user.has_effect("Great Thriving Forest", EffectType.Type.DELAY, user)
		if delay:
			delay.mag = 2
	else:
		for character in context['battle'].all_characters():
			for effect in character.effects.get_effects_by_type(EffectType.Type.DELAYED_SKILL):
				effect.duration += 2
				user.manually_advance_mission(10, 1)
			for effect in character.effects.get_effects_by_type(EffectType.Type.DELAY_MARKER):
				effect.duration += 2
	
	
func wrapup_trigger(context):
	var forest = user.has_effect("Great Thriving Forest", EffectType.Type.DELAY, user)
	if forest:
		forest.mag = 1

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 90)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
