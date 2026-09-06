extends Ability

func describe(user):
	return "Deals 20 damage to target enemy and for 1 turn, that enemy cannot increase the damage they deal with any effect. This skill will deal +5 damage each time it is used."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["For 1 turn, the target cannot increase the damage it deals with any effect", Color.CADET_BLUE],
		["Permanently deals +5 more damage each time this skill is used", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		var nb = Effect.no_boost_effect(2)   # 1 turn
		nb.set_source(self)
		Character.add_hostile_effect(context, user, target, nb)
	# +5 to every future Trap of Argalia (per-stack DAMAGE_MOD on Astolfo, keyed to this skill's name).
	# Added AFTER the hit, so use 1 = 20, use 2 = 25, use 3 = 30, ...
	var existing = user.has_effect("Trap of Argalia", EffectType.Type.DAMAGE_MOD, user)
	if existing:
		existing.stacks += 1
		existing.effect_updated.emit(existing)
	else:
		var boost = Effect.damage_mod_effect(5, -1, ["Trap of Argalia"])
		boost.set_source(self)
		boost.stackable = true
		boost.per_stack = true
		boost.display_stacks = true
		Character.add_allied_effect(context, user, user, boost)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
