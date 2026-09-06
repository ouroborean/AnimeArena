extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, if target enemy uses a new Helpful skill, they will be countered and banished for 1 turn. If the target is marked by Grisly Wing, they will be banished for 2 turns instead."

func split_desc():
	return [
		"For 1 turn, if target enemy uses a new Helpful skill, they are countered and banished for 1 turn",
		["Banished for 2 turns instead if the target is marked by Grisly Wing", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter_eff = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_USE, 2, "If this character uses a new Helpful skill, they will be countered and banished.", ["Helpful"])
		counter_eff.set_source(self)
		counter_eff.invisible = true
		counter_eff.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, counter_eff)


func counter_trigger(context):
	var victim = context['owner']
	var myotis = context['effect'].user
	var duration = 3
	if victim.marked_by("Grisly Wing", myotis):
		duration += 2
	user.manually_advance_mission(8, duration / 2)
	
	myotis.banish_character(context, victim, context['effect'].source, duration)
	default_counter_trigger(context)
	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
