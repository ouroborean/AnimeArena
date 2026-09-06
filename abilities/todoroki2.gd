extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 Affliction damage to target enemy. Deals +10 Affliction per stack of Half-Hot on Todoroki. Todoroki gains 1 Half-Hot and loses 1 Half-Cold."

func split_desc():
	return [
		"20 Affliction damage to target enemy.",
		["+10 Affliction per stack of Half-Hot on Todoroki.", Color.CADET_BLUE],
		["+1 Half-Hot / -1 Half-Cold on Todoroki.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var passive = _get_passive(user)
	var hot = passive.get_hot_stacks(user) if passive else 0
	var damage = base_damage + 10 * hot
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, DamageType.Type.AFFLICTION)
	if passive:
		passive.add_hot_stack(user)
		passive.remove_cold_stack(user)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 40)

func target(user, battle):
	default_hostile_target_function(user, battle)

func _get_passive(user):
	for ab in user.moveset.abilities:
		if ab.ability_name == "Half-Hot Half-Cold":
			return ab
	return null
