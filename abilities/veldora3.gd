extends Ability

var base_damage = 20
var stack_threshold = 3

func describe(user):
	return "Deals 20 damage to target enemy. While Veldora has 3 or more stacks of Slumbering Dragon, this skill targets all enemies."

func split_desc():
	return [
		"Deals 20 damage to target enemy.",
		["Targets all enemies while Veldora has 3 or more stacks of Slumbering Dragon.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.ENERGY)

func _slumbering_stacks(user):
	var sd = user.has_effect("Slumbering Dragon", EffectType.Type.DAMAGE_MOD, user)
	if sd:
		return sd.stacks
	return 0

func extra_usable(user):
	return true

func custom_behavior(context):
	if _slumbering_stacks(user) >= stack_threshold:
		return behavior_hostile_aoe_damage(context, 25, 1.0)
	return behavior_single_target_damage(context, 0, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
