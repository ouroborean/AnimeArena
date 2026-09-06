extends Ability

var base_damage = 0

func describe(user):
	return "Deals 0 Affliction damage to all enemies, +10 per stack of Half-Hot on Todoroki. Todoroki becomes Invulnerable for 1 turn. Todoroki gains 1 Half-Hot and loses 1 Half-Cold."

func split_desc():
	return [
		"0 Affliction damage to all enemies.",
		["+10 Affliction per stack of Half-Hot on Todoroki.", Color.CADET_BLUE],
		"Todoroki is Invulnerable for 1 turn.",
		["+1 Half-Hot / -1 Half-Cold on Todoroki.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var passive = _get_passive(user)
	var hot = passive.get_hot_stacks(user) if passive else 0
	var damage = base_damage + 10 * hot
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, DamageType.Type.AFFLICTION)
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	if passive:
		passive.add_hot_stack(user)
		passive.remove_cold_stack(user)

func extra_usable(user):
	return true

func custom_behavior(context):
	var passive = _get_passive(user)
	var hot = passive.get_hot_stacks(user) if passive else 0
	if hot >= 2:
		return behavior_hostile_aoe_damage(context, 60, 1.1)
	return behavior_self_panic_button(context, 30)

func target(user, battle):
	default_hostile_target_function(user, battle)

func _get_passive(user):
	for ab in user.moveset.abilities:
		if ab.ability_name == "Half-Hot Half-Cold":
			return ab
	return null
