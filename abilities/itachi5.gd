extends Ability


func describe(user):
	return "Deals 30 Piercing damage to target enemy. For 1 turn, that enemy cannot use skills (this is not a stun effect)."


func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy",
		"For 1 turn, that enemy cannot use skills (not a stun)",
	]


func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.PIERCING)
		# Duration 3 covers the target's one sealed turn AND survives into
		# Itachi's following turn so Yasaka Magatama can read the seal for
		# its damage bonus. The target only loses one turn — by Itachi's
		# turn-end the mark ticks to 0 and is removed.
		var seal = Effect.mark(3, "This character cannot use skills (sealed by Totsuka Blade).")
		seal.skill_seal = true
		apply_hostile(context, target, seal, true)


func extra_usable(user):
	return true


func custom_behavior(context):
	return behavior_single_target_damage(context, 80, 1.2, true)


func target(user, battle):
	default_hostile_target_function(user, battle, true)
