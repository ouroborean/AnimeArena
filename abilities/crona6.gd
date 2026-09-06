extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For the first 3 turns of the game, Crona's colored energy costs are changed to Random costs",
		["The effect is extended by 1 turn each time Crona takes damage", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(7, "Crona's colored costs have changed to Random costs.")
	mark.set_source(self)
	var red_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.RED, 7)
	red_change.system = true
	red_change.set_source(self)
	var blue_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.BLUE, 7)
	blue_change.set_source(self)
	blue_change.system = true
	var green_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.GREEN, 7)
	green_change.set_source(self)
	green_change.system = true
	var white_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.WHITE, 7)
	white_change.set_source(self)
	white_change.system = true

	var damage_trigger = Effect.trigger_effect(Trigger.always(trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "If Crona takes damage, the duration of Partner: Ragnarok is extended by 1 turn.")
	damage_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, damage_trigger)
	Character.add_allied_effect(context, user, user, red_change)
	Character.add_allied_effect(context, user, user, blue_change)
	Character.add_allied_effect(context, user, user, green_change)
	Character.add_allied_effect(context, user, user, white_change)
	
	
func trigger(context):
	for effect in user.effects.get_all_effects_by_name("Partner: Ragnarok"):
		if not effect.duration == -1:
			effect.duration += 2
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
