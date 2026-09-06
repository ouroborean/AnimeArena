extends Ability

# Barrier Pressure. Single-enemy control combo: 1-turn full stun, -15 non-Affliction damage for 2 turns,
# Isolate for 3 turns, and 15 Piercing damage per turn during that window. If an enemy has taxed this
# skill's cost to include Random energy, the control effects (and the damage window that tracks them)
# each last 1 more turn.

func describe(user):
	return "Stuns target enemy for 1 turn, lowers their non-Affliction damage by 15 for 2 turns, and Isolates them for 3 turns. During this time they take 15 Piercing damage per turn. If this skill costs at least 1 Random energy, its non-damage effects each last 1 more turn."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy per turn while affected",
		["Stuns them for 1 turn", Color.ORANGE_RED],
		["Lowers their non-Affliction damage by 15 for 2 turns", Color.CADET_BLUE],
		["Isolates them for 3 turns", Color.ORANGE_RED],
		["If this skill costs at least 1 Random energy, its non-damage effects last 1 more turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Base cost has no Random, so this is only true when an enemy raised the cost. +2 duration = +1 turn.
	var extend = 2 if cost()[Energy.Type.RANDOM] >= 1 else 0
	for target in user.targeter.targets:
		# Full stun (no class filter), dur 2 = 1 turn.
		var stun = Effect.stun_effect(2 + extend)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		# -15 to every damage type EXCEPT Affliction (exclusion_targets is the 5th arg), dur 4 = 2 turns.
		var weaken = Effect.damage_mod_effect(-15, 4 + extend, [], [], [DamageType.Type.AFFLICTION])
		weaken.set_source(self)
		Character.add_hostile_effect(context, user, target, weaken)
		# Isolate, dur 6 = 3 turns.
		var iso = Effect.isolate(6 + extend)
		iso.set_source(self)
		Character.add_hostile_effect(context, user, target, iso)
		# 15 Piercing DoT covering the window: immediate hit + damage_effect(dur 2N-1 = 5 for 3 turns),
		# extended alongside the isolate so "during this time" stays covered.
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
		var dot = Effect.damage_effect(15, DamageType.Type.PIERCING, 5 + extend)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, false)
