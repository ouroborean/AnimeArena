extends Ability

var base_damage = 30
var pre_damage = 0

func describe(user):
	return "Deals 30 damage to target enemy. Any time Damage Reduction, Shield, Nullify, or hostile damage mods affect this skill's damage, it permanently deals more damage proportional to the mitigated damage."

func split_desc():
	return [
		"Deals 30 damage to target enemy.",
		"If this skill's damage is reduced by Damage Reduction, Shield, or Nullify, its damage is permanently increased by 5",
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context)

func target(user, battle):
	default_hostile_target_function(user, battle)
