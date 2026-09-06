extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"The first 4 times Tengen uses a skill, he marks a random enemy with The Score with a matching number",
		["Once triggered 4 times, Tengen's cooldowns reset and his skills become free and Uncounterable until he attacks an unmarked enemy or a marked enemy out of order", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var tracker = Effect.empty(-1, "Uzui is building The Score.")
	tracker.set_source(self)
	tracker.mag = 0
	tracker.display_mag = true
	Character.add_allied_effect(context, user, user, tracker)
	var trigger = Effect.trigger_effect(Trigger.always(score_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "When Uzui uses a skill, he marks a random enemy with The Score.")
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func score_trigger(context):
	var tracker = user.has_effect("The Score", EffectType.Type.EMPTY)
	if not tracker:
		return
	tracker.mag += 1
	var count = int(tracker.mag)
	var enemies = []
	for character in user.battle.all_characters():
		if user.is_hostile(character) and not character.dead and not character.banished:
			enemies.append(character)
	if len(enemies) > 0:
		var target_index = user.battle.roll(0, len(enemies) - 1)
		var mark_target = enemies[target_index]
		var score_mark = Effect.mark(-1, "This character has been marked with The Score #" + str(count) + ".")
		score_mark.set_source(self)
		score_mark.mag = count
		score_mark.unique_render_id = randi_range(5, 1000000)
		score_mark.display_mag = true
		Character.add_hostile_effect(context, user, mark_target, score_mark)
	if count >= 4:
		user.effects.erase_effect(tracker)
		user.effects.erase_effect(context['effect'])
		for i in range(len(user.moveset.base_abilities)):
			if i < 4:
				user.moveset.base_abilities[i].cooldown_remaining = 0
		var free = Effect.cost_change_effect({}, -1)
		free.set_source(self)
		free.cleansable = false
		Character.add_allied_effect(context, user, user, free)
		var uncounter = Effect.ignore_counter_effect(-1)
		uncounter.set_source(self)
		uncounter.cleansable = false
		Character.add_allied_effect(context, user, user, uncounter)
		var empowered = Effect.mark(-1, "Uzui's skills are free and Uncounterable. He must attack Score-marked enemies in order.")
		empowered.set_source(self)
		empowered.mag = 1
		empowered.display_mag = true
		empowered.cleansable = false
		Character.add_allied_effect(context, user, user, empowered)
		var order_trigger = Effect.trigger_effect(Trigger.always(order_check), EffectType.Type.ACTION_USE_TRIGGER, -1, "If Uzui attacks an unmarked or out-of-order enemy, his empowered state ends.")
		order_trigger.set_source(self)
		Character.add_allied_effect(context, user, user, order_trigger)

func order_check(context):
	if not context.source is Ability:
		return
	if not context.source.classes["Harmful"]:
		return
	var empowered = user.has_effect("The Score", EffectType.Type.MARK)
	if not empowered:
		return
	var next_num = int(empowered.mag)
	for target in context['owner'].targeter.targets:
		if not user.is_hostile(target):
			continue
		var has_correct_mark = false
		for eff in target.effects.get_effects_by_type(EffectType.Type.MARK):
			if eff.source.ability_name == "The Score" and int(eff.mag) == next_num:
				has_correct_mark = true
				break
		if has_correct_mark:
			empowered.mag = next_num + 1
		else:
			end_empowered_state()
			return

func end_empowered_state():
	user.effects.full_remove_effect_by_name("The Score", user)

func extra_usable(user):
	return false

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	pass
