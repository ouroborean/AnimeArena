extends Ability

# Impossible Speed (Green form swap-in — hidden index 4, pulled into slot 2 by Summon - Beru).
# 30 Piercing (the Bypassing class lets it strike through the target's Invulnerability at the call
# site) + Jin-woo becomes Invulnerable for 1 turn.

func describe(user):
	return "Deals 30 Piercing damage to target enemy (bypasses Invulnerability) and Jin-woo becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy (bypasses Invulnerability)",
		["Jin-woo becomes Invulnerable for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.PIERCING)
	default_defend(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 30, 1.0, true)
	return variations

func target(user, battle):
	# Bypassing: the 3rd arg lets a human player SELECT an Invulnerable enemy (the class alone only
	# lets the damage pierce once targeted — targeting is gated separately). Mirrors cell7.gd.
	default_hostile_target_function(user, battle, true)
