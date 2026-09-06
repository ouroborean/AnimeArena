extends Ability

func describe(user):
	return "Horohoro marks all enemies for 2 turns. Horohoro's other Harmful skills will stun marked enemies for 1 turn. During this time, any enemy that uses a Harmful skill will take 15 damage."

func split_desc():
	return [
		"Marks all enemies for 2 turns (refreshes)",
		"Horohoro's other Harmful skills stun marked enemies for 1 turn",
		"Any marked enemy that uses a Harmful skill takes 15 damage",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		apply_frostbite(context, user, target, 5)

		var retal = Effect.trigger_effect(
			Trigger.always(retaliate_15),
			EffectType.Type.ACTION_USE_TRIGGER,
			4,
			"If this enemy uses a Harmful skill, they take 15 damage.")
		retal.set_source(self)
		Character.add_hostile_effect(context, user, target, retal)

func apply_frostbite(context, user, target, duration):
	if not target.has_effect("Frost That Rouses The Sleeping", EffectType.Type.ACTION_RECEIVE_TRIGGER):
		var trig = Effect.trigger_effect(
			Trigger.always(frostbite_stun),
			EffectType.Type.ACTION_RECEIVE_TRIGGER,
			duration,
			"Horohoro's other Harmful skills will stun this enemy for 1 turn.")
		trig.set_source(self)
		Character.add_hostile_effect(context, user, target, trig)
	else:
		target.has_effect("Frost That Rouses The Sleeping", EffectType.Type.ACTION_RECEIVE_TRIGGER).duration = 5

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

func retaliate_15(context):
	var enemy = context['target']
	var ability = context['source']
	var eff = context['effect']
	if not ability is Ability:
		return
	if not ability.classes["Harmful"]:
		return
	if enemy.dead or enemy.banished:
		return
	Character.resolve_effect_damage(context, eff, enemy, 15, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 50, 1.1)

func target(user, battle):
	default_hostile_target_function(user, battle)
