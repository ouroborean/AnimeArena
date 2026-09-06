extends Ability

# Dark Creation (passive). Auto-runs once at battle start via startup_passives.

func describe(user):
	return "BlackWarGreymon is permanently Isolated and ignores all non-damage effects."

func split_desc():
	return [
		["Permanently Isolated", Color.CADET_BLUE],
		["Ignores all negative non-damage effects", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var iso = Effect.isolate(-1)
	iso.set_source(self)
	iso.cleansable = false
	Character.add_allied_effect(context, user, user, iso)
	var ind = Effect.ignore_non_damage_effect(-1)
	ind.set_source(self)
	ind.cleansable = false
	Character.add_allied_effect(context, user, user, ind)

func extra_usable(user):
	return true

func target(user, battle):
	default_self_target_function(user, battle)
