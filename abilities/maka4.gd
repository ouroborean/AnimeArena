extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, Maka will counter all Physical skills that targets her. If she is wielding Soul, this skill has a 2 turn cooldown. This effect is invisible."

func split_desc():
	return [
		"For 1 turn, Maka counters all Physical skills that target her",
		["Has a 2-turn cooldown while wielding Soul", Color.CADET_BLUE],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var counter_eff = Effect.counter_effect(Trigger.always(maka_counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "Maka will counter all physical skills that target her.", ["Physical"])
	counter_eff.set_source(self)
	counter_eff.invisible = true
	counter_eff.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, counter_eff)

func maka_counter_trigger(context):
	var countered_target = context['owner']
	var counter_eff_target = context['target']
	var counter_user = context['effect'].user
	
	var notification_effect = Effect.counter_notification_effect(self)
	notification_effect.set_source(self)
	Character.add_hostile_effect(context, counter_user, countered_target, notification_effect)
	default_counter_trigger(context)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 10)
	
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
