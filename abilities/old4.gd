extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sayaka targets herself or an ally for one turn. The first harmful skill used on them will be countered. If this effect is not triggered, Sayaka heals 15 health."

func split_desc():
	return [
		"Counters the first Harmful skill used on Sayaka or target ally for 1 turn",
		["Sayaka heals 15 HP if this effect isn't triggered", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter_eff = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "The first harmful skill used on this character will be countered.", ["Harmful"])
		counter_eff.set_source(self)
		counter_eff.wrapup_func = counter_timeout
		counter_eff.invisible = true
		Character.add_allied_effect(context, user, target, counter_eff)

func counter_timeout(context):
	Character.resolve_effect_healing(context, context['effect'], context['effect'].target, 15)
	default_counter_timeout(context)

func counter_trigger(context):
	default_counter_trigger(context)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 30, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
