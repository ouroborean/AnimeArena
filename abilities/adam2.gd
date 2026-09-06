extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "For 1 turn, Adam will counter the next Harmful skill used on him and immediately use that same skill on the attacking enemy, then copy it for 2 turns (replacing Divine Counter). Adam gains 1 stack of Eye Strain."

func split_desc():
	return [
		"For 1 turn, counters the next Harmful skill used on Adam",
		["Uses that skill on the attacker, then copies it for 2 turns (replacing this skill)", Color.CADET_BLUE],
		["Adam gains 1 stack of Eye Strain", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var counter = Effect.counter_effect(Trigger.always(divine_counter_fired), EffectType.Type.COUNTER_RECEIVE, 2, "The next Harmful skill used on Adam is countered and reflected onto its user.", ["Harmful"])
	counter.wrapup_func = default_counter_timeout
	counter.invisible = true
	counter.set_source(self)
	Character.add_allied_effect(context, user, user, counter)
	user.moveset.base_abilities[4].grant_eye_strain(user)

func divine_counter_fired(context):
	# Fired from Character.countered(): owner is the attacker, context['effect'].user is Adam.
	var adam = context['effect'].user
	var attacker = context['owner']
	var stolen = attacker.used_ability
	if stolen != null and not (adam.dead or adam.banished or attacker.dead or attacker.banished):
		# Re-execute the stolen skill on the fly, as Adam, aimed at the attacker.
		# Save/set/restore mirrors byakuya5.gd:50-62.
		var tgt_storage = adam.targeter.targets
		var main_storage = adam.targeter.main_target
		var used_storage = adam.used_ability
		var stolen_user_save = stolen.user
		stolen.user = adam
		adam.used_ability = stolen
		adam.targeter.targets = [attacker]
		adam.targeter.main_target = attacker
		stolen.execute(adam, adam.battle)
		adam.check_ability_use_triggers(adam.battle, stolen)
		adam.targeter.targets = tgt_storage
		adam.targeter.main_target = main_storage
		adam.used_ability = used_storage
		stolen.user = stolen_user_save
		# Copy the stolen skill into Divine Counter's slot for 2 turns.
		var slot = adam.moveset.get_active_abilities(adam).find(self)
		if slot == -1:
			slot = 1
		var copy = Effect.copy_effect(stolen, slot, 5, adam)
		copy.unique_render_id = int(Time.get_ticks_msec())
		copy.set_source(self)
		Character.add_allied_effect(context, adam, adam, copy)
	# Consume the counter and notify the attacker; Character.countered() aborts the incoming skill.
	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 45, 1.0)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
