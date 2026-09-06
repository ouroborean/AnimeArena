extends Ability

# Gungnir (passive). Accumulates cumulative TEAM damage-taken via one DAMAGE_RECEIVE_TRIGGER per
# teammate. Every 50 total, grants a "Gungnir Charge" (Hibiki's next Amalgam/Alchemic Gold strikes
# twice — consumed one per double-strike). On the 3rd threshold, Ex-Drive and Berserk Mode become free.

func describe(user):
	return "Each time Hibiki's team has taken 50 total damage, Hibiki's next Amalgam or Alchemic Gold will strike twice. The third time this happens, Ex-Drive and Berserk Mode become free for the rest of the game."

func split_desc():
	return [
		"Each time Hibiki's team takes 50 total damage, her next Amalgam or Alchemic Gold strikes twice",
		["The third time, Ex-Drive and Berserk Mode become free for the rest of the game", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# single running counter on Hibiki: mag = damage since the last threshold, stacks = thresholds reached
	var counter = Effect.mark(-1, func(eff): return "Gungnir: " + str(eff.mag) + " / 50 team damage toward the next double-strike.")
	counter.set_source(self)
	counter.system = true
	counter.display_system = true   # visible to BOTH players (opts out of system-hiding, keeps cleanse-survival)
	counter.display_mag = true      # show the running team-damage total
	counter.unique_render_id = 1    # distinct tooltip from the Gungnir Charge (double-use) counter below
	counter.remove_on_death = false
	counter.cleansable = false   # else death-cleanse phase 2 (cleansable strip) erases it on Hibiki's death / a dispel, killing the passive
	counter.mag = 0
	counter.stacks = 0
	Character.add_allied_effect(context, user, user, counter)
	# one damage-taken watcher per teammate (includes Hibiki)
	for c in user.team.characters:
		var w = Effect.trigger_effect(Trigger.always(on_team_damaged), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "")
		w.set_source(self)
		w.system = true
		w.remove_on_death = false   # survive Hibiki's death-cleanse (phase 1 strips user==self unless system+remove_on_death=false)
		Character.add_allied_effect(context, user, c, w)

func on_team_damaged(context):
	var holder = context['effect'].user   # Hibiki (applier of the watcher)
	if holder == null or holder.dead or holder.banished:
		return
	var counter = holder.has_effect("Gungnir", EffectType.Type.MARK, holder)
	if counter == null:
		return
	counter.mag += context['value']
	var qc = QueryContext.from_game_state(holder, holder.battle)
	while counter.mag >= 50:                      # while, not if — one hit can cross several thresholds
		counter.mag -= 50
		counter.stacks += 1
		# grant one strike-twice charge (stackable)
		var existing = holder.has_effect("Gungnir Charge", EffectType.Type.MARK, holder)
		if existing:
			existing.stacks += 1
			existing.effect_updated.emit(existing)
		else:
			var charge = Effect.mark(-1, "Hibiki's next Amalgam or Alchemic Gold strikes twice.")
			charge.set_source(self)
			charge.name_override = "Gungnir Charge"
			charge.stackable = true
			charge.display_stacks = true
			charge.unique_render_id = 2   # distinct tooltip from the team-damage counter above
			charge.stacks = 1
			Character.add_allied_effect(qc, holder, holder, charge)
		if counter.stacks == 3:
			var free = Effect.cost_change_effect({}, -1, ["Ex-Drive", "Berserk Mode"])
			free.set_source(self)
			free.cleansable = false
			free.remove_on_death = false
			free.system = true   # "rest of the game" + can't be re-earned -> must survive death-cleanse phase 1 (revive)
			Character.add_allied_effect(qc, holder, holder, free)
	counter.effect_updated.emit(counter)

func extra_usable(user):
	return true

func custom_behavior(context):
	return []

func target(user, battle):
	default_self_target_function(user, battle)
