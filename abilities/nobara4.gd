extends Ability

# Embrace Pain. A 2-turn instant-kill/execute immunity. At the end of each of Nobara's turns she now
# ALWAYS heals 15 HP and gains 10 DR — bumped to 30 HP / 20 DR whenever she is currently carrying a
# negative non-damage effect.

const NEGATIVE_TYPES = [
	EffectType.Type.STUN,
	EffectType.Type.DAMAGE_MOD,
	EffectType.Type.DEF_NEGATE,
	EffectType.Type.DAMAGE_NEGATE,
	EffectType.Type.COST_CHANGE,
	EffectType.Type.COST_MOD,
	EffectType.Type.COUNTER_USE,
	EffectType.Type.COUNTER_RECEIVE,
	EffectType.Type.REFLECT_USE,
	EffectType.Type.REFLECT_RECEIVE,
	EffectType.Type.HEALING_MOD,
	EffectType.Type.VULNERABILITY,
	EffectType.Type.BLIND,
	EffectType.Type.DAMAGE_NULLIFICATION,
	EffectType.Type.COOLDOWN_MOD,
	EffectType.Type.DELAY,
	EffectType.Type.ISOLATE,
	EffectType.Type.TAUNT,
	EffectType.Type.PARALYZE,
	EffectType.Type.HEAL_CUT,
	EffectType.Type.DAMAGE_CAP,
	EffectType.Type.HEALTH_CAP,
]

func describe(user):
	return "For 2 turns, Nobara will ignore instant-kill and execute effects. At the end of each of her turns she heals 15 HP and gains 10 Damage Reduction, increased to 30 HP and 20 DR if she is affected by a negative non-damage effect. Usable while stunned."

func split_desc():
	return [
		["For 2 turns, Nobara ignores instant-kill and execute effects", Color.CADET_BLUE],
		["At the end of each of her turns she heals 15 HP and gains 10 Damage Reduction", Color.CADET_BLUE],
		["Increased to 30 HP and 20 DR if she is affected by a negative non-damage effect", Color.ORANGE_RED],
		["Usable while stunned", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(4, "Nobara will ignore instant-kill and execute effects.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	var tick = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, 3, "At the end of Nobara's turn she heals 15 HP and gains 10 DR, increased to 30 and 20 if she is affected by a negative non-damage effect.")
	tick.set_source(self)
	Character.add_allied_effect(context, user, user, tick)
	# Manual first instance: ticking triggers never fire the turn they are planted.
	_heal_and_guard(context, user, null)

func tick_trigger(context):
	_heal_and_guard(context, user, context['effect'])

func _heal_and_guard(context, nobara, source_effect):
	var boosted = _has_negative_effect(nobara)
	var heal = 30 if boosted else 15
	var dr_mag = 20 if boosted else 10
	if source_effect == null:
		Character.resolve_healing(context, nobara, heal)
	else:
		Character.resolve_effect_healing(context, source_effect, nobara, heal)
	var dr = Effect.damage_reduction_effect(dr_mag, 2)
	dr.set_source(self)
	dr.unique_render_id = 5
	Character.add_allied_effect(context, nobara, nobara, dr)

func _has_negative_effect(nobara):
	for effect in nobara.effects._effects:
		if not nobara.is_hostile(effect.user):
			continue
		if effect.effect_type in NEGATIVE_TYPES:
			return true
	return false

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 20)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
