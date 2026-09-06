extends Ability

func describe(user):
	return "Denji permanently deals 5 more damage with all non-Bleed skills and effects."

func split_desc():
	return [
		"Denji permanently deals 5 more damage with all skills and effects, except Bleed (stacks)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Blank (no ability/class filter) damage-mod: get_true_damage applies it on BOTH the direct-hit and
	# DoT-tick paths, so "+5 to all skills and effects" is automatic. Stacks each cast. BLEED is in
	# exclusion_targets so get_true_damage skips this boost for Denji's Bleed (direct + DoT ticks).
	var boost = Effect.damage_mod_effect(5, -1, [], [], [DamageType.Type.BLEED])
	boost.set_source(self)
	boost.stackable = true
	boost.stack_mag = true
	boost.display_stacks = true
	Character.add_allied_effect(context, user, user, boost)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([120, [user, self, [user]]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
