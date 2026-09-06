extends Ability

# Lab Experiment. Muzan experiments on one of his own: the ally takes 15 Bleed and is given a Random
# energy, and Muzan stores a stacking +10 boost for his next Blood Gash / Blood Demon Art: Assimilation.

func describe(user):
	return "Target ally takes 15 Bleed damage and gains 1 Random energy. Increases the damage or healing of Muzan's next Blood Gash or Blood Demon Art: Assimilation by 10 until it is next used (stacks)."

func split_desc():
	return [
		"Target ally takes 15 Bleed damage and gains 1 Random energy",
		["Muzan's next Blood Gash / Assimilation deals or heals +10, until used (stacks)", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.BLEED)
		target.gain_random_energy()
	# Stacking boost on Muzan; re-applying a stackable MARK adds a stack. Named "Lab Experiment" so the
	# blood skills read it via has_effect("Lab Experiment", MARK, user).
	var boost = Effect.mark(-1, "Muzan's next Blood Gash / Assimilation deals or heals +10 (stacks).")
	boost.stackable = true
	boost.display_stacks = true
	boost.set_source(self)
	Character.add_allied_effect(context, user, user, boost)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_selfless_helpful(context, 15)

func target(user, battle):
	default_allied_target_function(user, battle)
