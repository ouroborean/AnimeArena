extends Ability

var base_damage = 25

func describe(user):
	return "Deals 25 damage to target enemy and marks them for 2 turns. Horohoro's other Harmful skills will stun marked enemies for 1 turn."

func split_desc():
	return [
		"Deals 25 damage to target enemy and marks them for 2 turns (refreshes)",
		"Horohoro's other Harmful skills stun marked enemies for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		apply_frostbite(context, user, target, 5)

func apply_frostbite(context, user, target, duration):
	if not target.has_effect("Icicle Sword", EffectType.Type.ACTION_RECEIVE_TRIGGER):
		var trig = Effect.trigger_effect(
			Trigger.always(frostbite_stun),
			EffectType.Type.ACTION_RECEIVE_TRIGGER,
			duration,
			"Horohoro's Harmful skills will stun this enemy for 1 turn.")
		trig.set_source(self)
		Character.add_hostile_effect(context, user, target, trig)
	else:
		target.has_effect("Icicle Sword", EffectType.Type.ACTION_RECEIVE_TRIGGER).duration = 5

func frostbite_stun(context):
	var ability = context['source']
	var target = context['target']
	var eff = context['effect']
	if not ability is Ability:
		return
	if not ability.classes["Harmful"]:
		return
	if ability.user != eff.user:
		return
	if not target.effects.get_effects_by_type(EffectType.Type.STUN).is_empty():
		return
	var stun = Effect.stun_effect(2)
	stun.set_source(eff.source)
	Character.add_hostile_effect(context, eff.user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 45, 1.2)

func target(user, battle):
	default_hostile_target_function(user, battle)
