extends Ability

# Kishin Hunter. Self-cleanses hostile effects off Death, then deals 50 Piercing to a target enemy,
# bypassing invulnerability. If an enemy has taxed this skill's cost to include Random energy
# (cost()[RANDOM] >= 1), it also strips the target's beneficial effects first.
#
# NOTE: the two cleanse helpers are named inversely to intuition —
#   cleanse_all_enemy_effects(c) strips the HOSTILE (enemy-applied) effects FROM c  -> Death's self-cleanse
#   cleanse_all_ally_effects(c)  strips c's OWN (ally/self) beneficial effects       -> the enemy buff-strip
# "Uncounterable" + "Bypassing" are declarative classes (honored by countered()/reflect_check() +
# the bypassing=true targeting arg); no code needed for them beyond the target() bypass.

func describe(user):
	return "Removes all effects placed on Death by enemies, then deals 50 Piercing damage to target enemy, bypassing invulnerability. If this skill costs at least 1 Random energy, first removes all beneficial effects from that enemy. Cannot be countered."

func split_desc():
	return [
		"Deals 50 Piercing damage to target enemy, bypassing invulnerability",
		["Removes all enemy effects from Death", Color.AQUAMARINE],
		["If this skill costs at least 1 Random energy, first removes all beneficial effects from the target", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Random-tax gate FIRST — the self-cleanse below removes the enemy's +Random COST_MOD off Death, so
	# reading cost() after it would always see the base (no-Random) cost and the buff-strip could never fire.
	var strip_buffs = cost()[Energy.Type.RANDOM] >= 1
	# Strip every cleansable hostile effect off Death himself (this also clears the +Random tax just read).
	user.effects.cleanse_all_enemy_effects(user)
	for target in user.targeter.targets:
		if strip_buffs:
			# Strip the target's own beneficial effects BEFORE the damage lands.
			target.effects.cleanse_all_ally_effects(target, user)
		Character.resolve_damage(context, target, 50, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 50, 1.0, true)
	return variations

func target(user, battle):
	# bypassing=true keeps invulnerable enemies selectable (Piercing alone does NOT pierce invuln).
	default_hostile_target_function(user, battle, true)
