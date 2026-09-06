extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"For 1 turn, this skill will swap to Raikiri",
		["If Touka receives a new Harmful skill during this time, that skill is countered, its user takes 15 damage, and this skill ends", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var nukiashi = user.marked_by("Nukiashi")
	
	
	# Swap Draw Stance (slot 0) with Raikiri (slot 4) for 1 turn
	var swap = Effect.ability_swap_effect(4, 0, user, 3)
	swap.set_source(self)
	if nukiashi:
		swap.invisible = true
		swap.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, swap)

	# Counter setup: any harmful skill used on Touka is countered, user takes 15 damage
	var trigger = Trigger.always(draw_counter_trigger)
	var counter = Effect.counter_effect(
		trigger,
		EffectType.Type.COUNTER_RECEIVE,
		3,
		"The next Harmful skill used on this character will be countered and its user will take 15 damage.",
		["Harmful"]   # scope to Harmful only; without this class_targets defaults to [] = counter ANY hostile skill (e.g. Ichibe's Strategic Ink Splatter)
	)
	counter.wrapup_func = default_counter_timeout
	if nukiashi:
		counter.invisible = true
	counter.set_source(self)
	Character.add_allied_effect(context, user, user, counter)

func draw_counter_trigger(context):
	var countered_character = context['owner']
	Character.resolve_effect_damage(
		context,
		context['effect'],
		countered_character,
		15,
		DamageType.Type.NORMAL
	)

	# End the swap effect early
	var touka = context['effect'].user
	touka.effects.remove_effect("Draw Stance", EffectType.Type.ABILITY_SWAP, touka)

	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 10)

func target(user, battle):
	default_self_target_function(user, battle)
