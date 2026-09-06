extends Ability

func describe(user):
	return "The Thompson Sisters alternate between two forms: Liz and Patty. When any ally begins wielding Liz or Patty, the other becomes active. Liz is the active sister at the start of the battle."

func split_desc():
	return [
		"The Thompson Sisters alternate between Liz and Patty.",
		["When any ally begins wielding a sister, the other becomes active.", Color.DIM_GRAY],
		["Liz is the active sister at the start of the battle.", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	pass

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)

# Active sister state is encoded as the `mag` of a single mark sourced from this
# passive (effect_name = "Brooklyn Devils"): mag == 0 means Liz is active, mag
# == 1 means Patty is active. The wielder package itself (mark + color change +
# trigger) is owned by Transform and managed there.

func set_active_sister(thompson, new_active: String, context):
	var mag_value = 0 if new_active == "Liz" else 1
	var existing = thompson.effects.has_effect("Brooklyn Devils", EffectType.Type.MARK, thompson)
	if existing != null:
		existing.mag = mag_value
	else:
		var active = Effect.mark(-1, new_active + " is currently the active Thompson Sister.")
		active.set_source(self)
		active.system = true
		active.mag = mag_value
		active.cleansable = false
		Character.add_allied_effect(context, thompson, thompson, active)

	# Wipe any prior slot 2/3 swaps installed by this passive, then re-install
	# them only when Patty is the active sister.
	for swap in thompson.get_ability_swap_effects():
		if swap.source != self:
			continue
		var slot_replace = int(swap.mag[1])
		if slot_replace == 2 or slot_replace == 3:
			thompson.effects.erase_effect(swap)

	if new_active == "Patty":
		var swap2 = Effect.ability_swap_effect(4, 2, thompson, -1)
		swap2.set_source(self)
		Character.add_allied_effect(context, thompson, thompson, swap2)
		var swap3 = Effect.ability_swap_effect(5, 3, thompson, -1)
		swap3.set_source(self)
		Character.add_allied_effect(context, thompson, thompson, swap3)

	# Death the Kid synergy: when Kid is dual-wielding, Transform's slot 0 swap
	# pairs with the passive's slot 2 swap so both WC skills stay available. Ask
	# Transform to re-pick its slot 0 swap now that active sister has flipped.
	for ch in thompson.battle.all_characters():
		var dual = ch.has_effect("Transform: Demon Twin Guns", EffectType.Type.MARK, thompson)
		if dual != null and dual.mag == 2:
			var transform = thompson.moveset.base_abilities[0]
			transform.refresh_kid_transform_swap(thompson, context)
			break

	# Portrait: Liz uses the base portrait (no portrait change), Patty uses the
	# first alternate portrait. Always strip any existing portrait change from
	# this passive before installing the new one.
	for portrait in thompson.effects.get_effects_by_type(EffectType.Type.PORTRAIT_CHANGE):
		if portrait.source == self:
			thompson.effects.erase_effect(portrait)

	if new_active == "Patty":
		var portrait_swap = Effect.portrait_change_effect(0, -1)
		portrait_swap.set_source(self)
		Character.add_allied_effect(context, thompson, thompson, portrait_swap)
