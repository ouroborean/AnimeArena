extends Ability

var base_damage = 30
var stack_threshold = 3

func describe(user):
	return "Deals 30 damage to target enemy. If Veldora has 3 or more stacks of Slumbering Dragon, this skill stuns its target for 1 turn."

func split_desc():
	return [
		"Deals 30 damage to target enemy.",
		["Stuns the target for 1 turn while Veldora has 3 or more stacks of Slumbering Dragon.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stacks = _slumbering_stacks(user)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.ENERGY)
		if stacks >= stack_threshold:
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)

func _slumbering_stacks(user):
	var sd = user.has_effect("Slumbering Dragon", EffectType.Type.DAMAGE_MOD, user)
	if sd:
		return sd.stacks
	return 0

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 5, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
