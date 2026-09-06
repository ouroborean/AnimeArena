extends Ability

var dot_damage = 15

func describe(user):
	return "Stuns target enemy for 1 turn and deals 15 damage per turn. Each effect lasts 1 more turn per stack of Half-Cold on Todoroki. Todoroki gains 1 Half-Cold and loses 1 Half-Hot."

func split_desc():
	return [
		"Stuns target enemy and deals 15 damage per turn for 1 turn.",
		["+1 turn per stack of Half-Cold on Todoroki.", Color.CADET_BLUE],
		["+1 Half-Cold / -1 Half-Hot on Todoroki.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var passive = _get_passive(user)
	var cold = passive.get_cold_stacks(user) if passive else 0
	var dur = 2 + (2 * cold)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(dur)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		var dot = Effect.damage_effect(dot_damage, DamageType.Type.NORMAL, dur)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)
	if passive:
		passive.add_cold_stack(user)
		passive.remove_hot_stack(user)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_stun(context, 45)

func target(user, battle):
	default_hostile_target_function(user, battle)

func _get_passive(user):
	for ab in user.moveset.abilities:
		if ab.ability_name == "Half-Hot Half-Cold":
			return ab
	return null
