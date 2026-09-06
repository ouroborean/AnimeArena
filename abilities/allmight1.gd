extends Ability

var base_damage = 40
var base_self_damage = 15

func describe(user):
	return "Deals 40 Piercing damage to target enemy. All Might takes 15 Affliction damage."

func split_desc():
	return [
		"Deals 40 Piercing damage to target enemy.",
		["All Might takes 15 Affliction damage.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	deal_damage_to_targets(context, base_damage, DamageType.Type.PIERCING)
	var bonus = 10 * get_stacks("Declare Successor", EffectType.Type.MARK)
	Character.resolve_damage(context, user, base_self_damage + bonus, DamageType.Type.AFFLICTION)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 20)

func target(user, battle):
	default_hostile_target_function(user, battle)
