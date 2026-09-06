extends Ability

# ODM Gear Assault — a 2-turn Piercing damage-over-time. Levi is invulnerable during the
# first turn of the assault, and afterwards Precision Strike costs 1 Random instead of 1 Green
# on his following turn. The DoT is one immediate instance plus a duration-3 damage_effect
# (which ticks once more on Levi's next turn = 2 total turns of damage; mirrors Playful Cloud).

var base_damage = 20

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy for 2 turns",
		["Levi is invulnerable during the first turn", Color.CADET_BLUE],
		["Afterward, Precision Strike costs 1 Random instead of 1 Green for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Invulnerable during the first turn of the assault (invuln_effect(2) = 1 turn).
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	# Precision Strike costs 1 Random instead of 1 Green on Levi's following turn.
	# Duration 3 = active through his next turn (durations tick each player's turn). Mirrors alphamon1.
	var cost_swap = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.GREEN, 3, ["Precision Strike"])
	cost_swap.set_source(self)
	cost_swap.refresh = true
	Character.add_allied_effect(context, user, user, cost_swap, true)
	for target in user.targeter.targets:
		# Duration-3 ticking DoT + one immediate instance = 2 turns of 20 Piercing (Playful Cloud pattern).
		var dot = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, 3)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 45)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
