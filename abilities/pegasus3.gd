extends Ability

var base_damage = 25

func describe(user):
	return "Pegasus marks target enemy for 1 turn (Invisible). If that enemy does not use a new skill during this time, they take 25 damage. If this effect is triggered while Pegasus has Shield from Relinquished, Relinquished will be permanently replaced by Thousand-Eyes Restrict."

func split_desc():
	return [
		"Marks target enemy for 1 turn (Invisible)",
		"If that enemy does not use a new skill during this time, they take 25 damage",
		"If this resolves while Pegasus carries the Relinquished Shield, Relinquished is permanently replaced by Thousand-Eyes Restrict"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var watch_trigger = Effect.trigger_effect(Trigger.always(skill_use_trigger), EffectType.Type.ACTION_USE_TRIGGER, 2, "If this character uses a new skill, this effect will end.")
		watch_trigger.invisible = true
		watch_trigger.waiting = false
		watch_trigger.wrapup_func = default_counter_timeout
		watch_trigger.set_source(self)

		var fail_trigger = Effect.trigger_effect(Trigger.always(damage_trigger), EffectType.Type.END_OF_TURN_TRIGGER, 2, "Pegasus will deal 25 damage to this character at the end of the turn.")
		fail_trigger.invisible = true
		fail_trigger.set_source(self)

		Character.add_hostile_effect(context, user, target, fail_trigger)
		Character.add_hostile_effect(context, user, target, watch_trigger)

func skill_use_trigger(context):
	context['effect'].target.effects.full_remove_effect_by_name("Dark-Eyes Illusionist", context['effect'].user)

func damage_trigger(context):
	if context['target'].acted:
		return
	Character.resolve_effect_damage(context, context['effect'], context['target'], base_damage, DamageType.Type.NORMAL)
	if user.has_effect("Relinquished", EffectType.Type.SHIELD, user):
		var swap = Effect.ability_swap_effect(4, 1, user, -1)
		swap.set_source(self)
		Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	var swap_bonus = 0
	if user.has_effect("Relinquished", EffectType.Type.SHIELD, user):
		swap_bonus = 50
	variations += behavior_single_target_hostile(context, 30 + swap_bonus)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
