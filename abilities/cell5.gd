extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "If an enemy dies under the effect of Absorption or fails to break its Nullify while it's active, Cell transforms. The first time this happens, Inherited Solar Flare is replaced by Rampant Energy Rain. The second time this happens, Rampant Energy Rain is replaced by Inherited Kamehameha and Absorption is replaced by Inherited Death Beam."

func split_desc():
	return [
		"Cell transforms when an enemy dies under Absorption or its Nullify expires unbroken",
		["1st transformation: Inherited Solar Flare → Rampant Energy Rain", Color.AQUAMARINE],
		["2nd transformation: Rampant Energy Rain → Inherited Kamehameha; Absorption → Inherited Death Beam", Color.AQUAMARINE],
		"Perfected Combat gains +5 damage per transformation (capped at 2)"
	]

func execute(user, battle):
	# Passive — no startup state. attempt_transformation is called by cell3
	# (Absorption) from both its nullify_expired_callback and death_trigger
	# callbacks. Doing it that way lets cell3 capture the live anchor mark to
	# de-duplicate triggers from the same cast (death + barrier-expiry
	# shouldn't both fire), which a global watcher here couldn't see.
	pass

# Called by cell3 when either of Genetic Perfection's trigger conditions fires.
# Increments the transformation counter and applies the appropriate ability
# swaps. Capped at 2 transformations — additional triggers are no-ops.
func attempt_transformation(context, cell):
	if cell == null or cell.dead or cell.banished:
		return
	var counter = cell.has_effect("Genetic Perfection", EffectType.Type.MARK, cell)
	var count_before = counter.stack_count() if counter else 0
	if count_before >= 2:
		return

	if counter:
		counter.stacks += 1
		counter.effect_updated.emit(counter)
	else:
		var stack_desc = func (eff):
			return "Cell has transformed " + str(eff.stack_count()) + " time(s). Each transformation boosts Perfected Combat by 5 damage."
		var m = Effect.mark(-1, stack_desc)
		m.set_source(self)
		m.stackable = true
		m.display_stacks = true
		m.stacks = 1
		m.cleansable = false
		Character.add_allied_effect(context, cell, cell, m, true)

	var new_count = count_before + 1
	if new_count == 1:
		# Slot 1 (Inherited Solar Flare) → Slot 5 (Rampant Energy Rain),
		# permanent.
		var swap1 = Effect.ability_swap_effect(5, 1, cell, -1)
		swap1.set_source(self)
		Character.add_allied_effect(context, cell, cell, swap1, true)
		var portrait_change = Effect.portrait_change_effect(0, -1)
		portrait_change.set_source(self)
		Character.add_allied_effect(context, cell, cell, portrait_change)
	elif new_count == 2:
		# Slot 1 (currently Rampant Energy Rain) → Slot 6 (Inherited
		# Kamehameha). Slot 2 (Absorption) → Slot 7 (Inherited Death Beam).
		user.effects.remove_effect("Genetic Perfection", EffectType.Type.PORTRAIT_CHANGE)
		
		var portrait_change = Effect.portrait_change_effect(1, -1)
		portrait_change.set_source(self)
		Character.add_allied_effect(context, cell, cell, portrait_change)
		var swap1 = Effect.ability_swap_effect(6, 1, cell, -1)
		swap1.set_source(self)
		var swap2 = Effect.ability_swap_effect(7, 2, cell, -1)
		swap2.set_source(self)
		Character.add_allied_effect(context, cell, cell, swap1, true)
		Character.add_allied_effect(context, cell, cell, swap2, true)

func extra_usable(user):
	return true

func target(user, battle):
	pass
