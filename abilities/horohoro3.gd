extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 damage to target enemy for 2 turns. If the target receives any new stun effects while active, this skill lasts an additional turn. Cannot be used while active."

func split_desc():
	return [
		"Deals 20 damage to target enemy for 2 turns",
		"Duration is extended by 1 turn whenever the target receives a new stun effect",
		["Cannot be used while active", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)

		var dot = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)

		var extender = Effect.trigger_effect(
			Trigger.always(extend_on_stun),
			EffectType.Type.STUN_RECEIVED_TRIGGER,
			4,
			"If this character receives a new stun, Nipopo Gauntlets is extended by 1 turn.")
		extender.set_source(self)
		Character.add_hostile_effect(context, user, target, extender)

func extend_on_stun(context):
	var target = context['target']
	var horohoro = context.effect.user
	var dot = target.has_effect("Nipopo Gauntlets", EffectType.Type.DAMAGE, horohoro)
	if dot == null:
		return
	dot.duration += 2
	dot.effect_updated.emit(dot)
	var me = context.effect
	me.duration += 2
	me.effect_updated.emit(me)

func extra_usable(user):
	for char in user.battle.all_characters():
		if user.is_hostile(char) and char.has_effect("Nipopo Gauntlets", EffectType.Type.DAMAGE, user):
			return false
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 35, 1.1)

func target(user, battle):
	default_hostile_target_function(user, battle)
