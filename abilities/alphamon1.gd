extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 damage to target enemy and Shatters them for 2 turns (refreshes). On your following turn, Digitalize of Soul costs 1 less Random energy."

func split_desc():
	return [
		"Deals 20 damage to target enemy.",
		"Shatters them for 2 turns (refreshes).",
		["On your following turn, Digitalize of Soul costs 1 less Random energy", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var shatter = Effect.def_negate(3)
		shatter.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter)
	# Reduce Digitalize of Soul's Random cost by 1 on Alphamon's following turn.
	# Duration 3 = active through his next turn (durations tick each player's turn). Mirrors cooler6.
	var cost_mod = Effect.cost_mod_effect(-1, 3, Energy.Type.RANDOM, ["Digitalize of Soul"])
	cost_mod.set_source(self)
	cost_mod.refresh = true
	Character.add_allied_effect(context, user, user, cost_mod, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context)

func target(user, battle):
	default_hostile_target_function(user, battle)
