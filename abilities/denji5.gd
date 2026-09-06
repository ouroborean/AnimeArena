extends Ability

func describe(user):
	return "Whenever Denji deals non-Bleed damage to a bleeding enemy, he heals the same amount."

func split_desc():
	return [
		["Whenever Denji deals non-Bleed damage to a bleeding enemy, he heals that amount", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trig = Effect.trigger_effect(Trigger.always(blood_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "When Denji deals non-Bleed damage to a bleeding enemy, he heals that amount.")
	trig.set_source(self)
	Character.add_allied_effect(context, user, user, trig)

func blood_trigger(context):
	if context.damage_type == DamageType.Type.BLEED:
		return
	var denji = context['effect'].user
	var target = context['target']
	if target == null or not denji.is_hostile(target):
		return
	var bleeding = false
	for e in target.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if e.damage_type == DamageType.Type.BLEED:
			bleeding = true
			break
	if not bleeding:
		return
	Character.resolve_effect_healing(context, context['effect'], denji, context['value'])

func extra_usable(user):
	return false

func custom_behavior(context):
	return []

func target(user, battle):
	pass
