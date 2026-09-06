extends Ability

func describe(user):
	return "Targets 1 enemy and gives them 10 Nullify, decreases non-Affliction damage they deal by 10 for 1 turn, and gives them a stack of Lady's Poison."

func split_desc():
	return [
		"Gives target enemy 10 Nullify.",
		"Decreases the target's non-Affliction damage by 10 for 1 turn.",
		["Applies 1 stack of Lady's Poison to the target.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var passive = user.moveset.base_abilities[4]
	for target in user.targeter.targets:
		var nullify = Effect.barrier_effect(10, -1)
		nullify.set_source(self)
		Character.add_hostile_effect(context, user, target, nullify)

		var weaken = Effect.damage_mod_effect(-10, 2, [], [], [DamageType.Type.AFFLICTION])
		weaken.set_source(self)
		Character.add_hostile_effect(context, user, target, weaken)

		var existing = target.has_effect("Lady's Poison", EffectType.Type.DAMAGE, user)
		if existing == null:
			Character.resolve_damage(context, target, 5, DamageType.Type.AFFLICTION)
		passive.apply_poison_stack(context, user, target)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_spread_out(context, "Lady's Poison", EffectType.Type.TICKING_TRIGGER, 30)

func target(user, battle):
	default_hostile_target_function(user, battle)
