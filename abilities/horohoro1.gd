extends Ability

func describe(user):
	return "For 4 turns, Kororo's skills are replaced by alternates. During this time, if he is Stunned, he ignores that effect and heals 20 HP."

func split_desc():
	return [
		"For 4 turns, Horohoro's skills are replaced by alternates",
		"If Horohoro is Stunned during this time, he ignores the Stun and heals 20 HP",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var swap = Effect.ability_swap_effect(4, 1, user, 9)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	var swap2 = Effect.ability_swap_effect(5, 2, user, 9)
	swap2.set_source(self)
	Character.add_allied_effect(context, user, user, swap2)
	var swap3 = Effect.ability_swap_effect(6, 3, user, 9)
	swap3.set_source(self)
	Character.add_allied_effect(context, user, user, swap3)

	var trig = Effect.trigger_effect(
		Trigger.always(stun_shrug),
		EffectType.Type.STUN_RECEIVED_TRIGGER,
		8,
		"If Horohoro is stunned, he ignores it and heals 20 HP.")
	trig.set_source(self)
	Character.add_allied_effect(context, user, user, trig)

	# TODO(phase 2): install ability_swap_effect for horohoro2..horohoro7 ↔ their alternates
	# var swap = Effect.ability_swap_effect(<alt_slot>, <base_slot>, user, 8)

func stun_shrug(context):
	var horohoro = context['target']
	var stun_source = context['source']
	if stun_source == null:
		return
	for stun in horohoro.effects.get_effects_by_type(EffectType.Type.STUN):
		if stun.source == stun_source:
			horohoro.effects.erase_effect(stun)
	Character.resolve_effect_healing(context, context.effect, horohoro, 20)

func extra_usable(user):
	return user.has_effect("Kororo Snowboard", EffectType.Type.MARK, user) == null

func custom_behavior(context):
	return behavior_self_panic_button(context, 25, 1.0)

func target(user, battle):
	default_self_target_function(user, battle)
