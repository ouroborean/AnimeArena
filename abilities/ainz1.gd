extends Ability

# Hold of Ribs (display slot 0). Isolates + Shatters a target enemy for 1 turn, +1 turn per EXTRA energy
# this skill costs (the passive's +Random cost bumps). While that window is active, slot 0 shows Fallen
# Down (base_abilities[5]).

func describe(user):
	return ""

func split_desc():
	return [
		"Target enemy is Isolated and Shattered for 1 turn",
		["Duration +1 turn for each extra energy this skill costs (from The Goal of all Life is Death)", Color.CADET_BLUE],
		["While active, this skill is replaced by Fallen Down", Color.AQUAMARINE],
	]

# "Extra energy this skill costs" = current effective cost total minus the printed base cost total.
func _extra_energy() -> int:
	var extra := 0
	var c = cost()
	for e in c:
		extra += c[e]
	for e in _cost:
		extra -= _cost[e]
	return max(0, extra)

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var turns = 1 + _extra_energy()
	var dur = turns * 2                       # "N turns" = 2N
	for target in user.targeter.targets:
		var iso = Effect.isolate(dur)
		iso.set_source(self)
		Character.add_hostile_effect(context, user, target, iso)
		var shatter = Effect.def_negate(dur)
		shatter.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter)
	# Replace slot 0 with Fallen Down for the same window (swap "N turns" = 2N+1).
	var swap = Effect.ability_swap_effect(5, 0, user, dur + 1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 30)

func target(user, battle):
	default_hostile_target_function(user, battle)
