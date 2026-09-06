extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target ally gains 1 stack of Doctor Blythe each turn for the rest of the game",
		["If used on an ally already affected, consumes both effects to heal the ally 10 HP for each stack consumed", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if not target.has_effect("Doctor Blythe", EffectType.Type.TICKING_TRIGGER):
			target.gain_mark(user, self, -1, "Doctor Blythe can be used to heal this character for 10 HP per stack, consuming both effects.", true)
			user.manually_advance_mission(10, 1)
			var tick = Effect.trigger_effect(Trigger.always(ticking_trigger), EffectType.Type.TICKING_TRIGGER, -1, "This character will gain one stack of Doctor Blythe.")
			tick.set_source(self)
			Character.add_allied_effect(context, user, target, tick)
		else:
			var stack_count = target.get_mark_stacks("Doctor Blythe")
			if stack_count >= 5:
				user.manually_advance_mission(7, 1)
			Character.resolve_healing(context, target, 10 * stack_count)
			target.effects.full_remove_effect_by_name("Doctor Blythe")

func ticking_trigger(context):
	context.target.gain_mark(user, self, -1, "Doctor Blythe can be used to heal this character for 10 HP per stack, consuming both effects.", true)
	user.manually_advance_mission(10, 1)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
