extends Ability

var base_damage = 20
var debuff_mag = -5

func describe(user):
	return "Deals 20 damage to target enemy. Target deals -5 non-Affliction damage for 1 turn, +1 turn per stack of Half-Cold on Todoroki. Todoroki gains 1 Half-Cold and loses 1 Half-Hot."

func split_desc():
	return [
		"20 damage to target enemy.",
		"Target deals -5 non-Affliction damage for 1 turn.",
		["+1 turn per stack of Half-Cold on Todoroki.", Color.CADET_BLUE],
		["+1 Half-Cold / -1 Half-Hot on Todoroki.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var passive = _get_passive(user)
	var cold = passive.get_cold_stacks(user) if passive else 0
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var mod = Effect.damage_mod_effect(debuff_mag, 2 + (2 * cold), [], [], [DamageType.Type.AFFLICTION])
		mod.set_source(self)
		Character.add_hostile_effect(context, user, target, mod)
	if passive:
		passive.add_cold_stack(user)
		passive.remove_hot_stack(user)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 30)

func target(user, battle):
	default_hostile_target_function(user, battle)

func _get_passive(user):
	for ab in user.moveset.abilities:
		if ab.ability_name == "Half-Hot Half-Cold":
			return ab
	return null
