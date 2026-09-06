extends Ability

# Muscle Magic (PASSIVE). Two permanent immunities:
#   * energy cannot be drained/stolen from Mash — a guard in Character.lose_energy keyed on the
#     "Muscle Magic" MARK skips the drain when the drainer is an enemy.
#   * Nullify cannot be applied to Mash — a permanent IGNORE_EFFECT of BARRIER makes add_hostile_effect
#     shrug it off (shrug_off_type(BARRIER) -> true).
# Both are permanent machinery: system + remove_on_death=false + cleansable=false so they survive the
# death-cleanse and a revive ([[permanent-machinery-death-cleanse]]); passives don't re-run on revive.

func describe(user):
	return ""

func split_desc():
	return [
		"Mash cannot have energy drained or stolen from him",
		["Mash cannot have Nullify applied to him", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.has_effect("Muscle Magic", EffectType.Type.MARK, user) == null:
		var mark = Effect.mark(-1, "Immune to energy drain/steal and Nullify.")
		mark.set_source(self)
		mark.system = true
		mark.remove_on_death = false
		mark.cleansable = false
		Character.add_allied_effect(context, user, user, mark)
	if user.has_effect("Muscle Magic", EffectType.Type.IGNORE_EFFECT, user) == null:
		var ign = Effect.ignore_effect_effect(-1, EffectType.Type.BARRIER)
		ign.set_source(self)
		ign.system = true
		ign.remove_on_death = false
		ign.cleansable = false
		Character.add_allied_effect(context, user, user, ign)
