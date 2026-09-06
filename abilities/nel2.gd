extends Ability

func describe(user):
	return "For 1 turn, if target enemy uses a Harmful skill, they are countered and this skill's cooldown is reset. Next turn, Nel can use this skill for no cost to deal 15 damage to that enemy; if a skill was countered, this damage is doubled to 30."

func split_desc():
	return [
		"For 1 turn, if target enemy uses a Harmful skill they are countered (Invisible)",
		["Next turn, Nel can reuse this skill for no cost to deal 15 damage to that enemy.", Color.CADET_BLUE],
		["If a skill was countered, that damage is doubled to 30.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ready = user.has_effect("Cero Doble", EffectType.Type.MARK, user)
	if ready:
		var damage = 30 if ready.mag >= 2 else 15
		for target in user.targeter.targets:
			Character.resolve_damage(context, target, damage, DamageType.Type.ENERGY)
		user.effects.full_remove_effect_by_name("Cero Doble", user)
		return

	for target in user.targeter.targets:
		var counter = Effect.counter_effect(
			Trigger.always(counter_trigger),
			EffectType.Type.COUNTER_USE,
			2,
			"If this character uses a new Harmful skill, they will be countered by Cero Doble.",
			["Harmful"])
		counter.wrapup_func = default_counter_timeout
		counter.invisible = true
		counter.set_source(self)
		Character.add_hostile_effect(context, user, target, counter)

	var ready_mark = Effect.mark(4, "Cero Doble follow-up is armed.")
	ready_mark.mag = 1
	ready_mark.invisible = true
	ready_mark.set_source(self)
	Character.add_allied_effect(context, user, user, ready_mark)

	var free = Effect.cost_change_effect({}, 4, ["Cero Doble"])
	free.set_source(self)
	free.invisible = true
	Character.add_allied_effect(context, user, user, free)

func counter_trigger(context):
	var nel = context['effect'].user
	var ready = nel.has_effect("Cero Doble", EffectType.Type.MARK, nel)
	if ready:
		ready.mag = 2
	cooldown_remaining = 0
	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 50)

func target(user, battle):
	default_hostile_target_function(user, battle)
