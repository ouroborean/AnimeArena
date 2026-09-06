extends Ability

func describe(user):
	return "Permanently, if Arthur's HP falls below 50, he will ignore damage for 1 turn and Violet Flash will change to Moon Splitting Violet Flash."

func split_desc():
	return [
		"Permanent: when Arthur's HP falls below 50, he ignores damage for the rest of the turn (invisible)",
		["When triggered, Violet Flash permanently becomes Moon Splitting Violet Flash", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = make_context(battle)

	var armed = Effect.mark(-1, "Star Ring is active.")
	armed.set_source(self)
	armed.invisible = true
	Character.add_allied_effect(context, user, user, armed)

	if user.health.hp < 50:
		star_ring_activate(context)
		return

	var trigger = Effect.trigger_effect(
		Trigger.from_condition(Condition.health_is(user, -1, 49), star_ring_activate),
		EffectType.Type.HEALTH_CHANGE_TRIGGER,
		-1,
		"When Arthur's HP falls below 50, he ignores damage for 1 turn and Violet Flash becomes Moon Splitting Violet Flash."
	)
	trigger.set_source(self)
	trigger.invisible = true
	Character.add_allied_effect(context, user, user, trigger)

func star_ring_activate(context):
	var arthur = context['owner']
	if arthur == null or arthur.dead or arthur.banished:
		return
	var qc = QueryContext.from_game_state(arthur, arthur.battle)

	var guard = Effect.ignore_damage_effect(1)
	guard.set_source(self)
	Character.add_allied_effect(qc, arthur, arthur, guard)

	swap_ability(qc, 4, 0, -1)

	arthur.effects.remove_effect("Star Ring", EffectType.Type.HEALTH_CHANGE_TRIGGER, arthur)

func extra_usable(user):
	return not user.has_effect("Star Ring", EffectType.Type.MARK, user)

func custom_behavior(context):
	return behavior_self_panic_button(context, 35)

func target(user, battle):
	default_self_target_function(user, battle)
