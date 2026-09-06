extends Ability

func describe(user):
	return "For 1 turn, the Thompson Sisters will ignore all harmful effects. At the end of this time, Liz will become the active Thompson Sister. If Transform: Demon Twin Guns is currently active, its target will begin wielding Patty instead."

func split_desc():
	return [
		"For 1 turn, the Thompson Sisters ignore all harmful effects.",
		"At the end, Liz becomes the active Thompson Sister.",
		["If Transform: Demon Twin Guns is active, its target will begin wielding Patty instead.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var ignore_dmg = Effect.ignore_damage_effect(2)
	ignore_dmg.set_source(self)
	ignore_dmg.wrapup_func = on_evasion_end
	var ignore_other = Effect.ignore_non_damage_effect(2)
	ignore_other.set_source(self)
	Character.add_allied_effect(context, user, user, ignore_dmg)
	Character.add_allied_effect(context, user, user, ignore_other)

func on_evasion_end(context):
	var thompson = context['owner']
	var passive = thompson.moveset.base_abilities[6]
	var transform = thompson.moveset.base_abilities[0]

	# Always flip the active sister: Patty -> Liz (CE: Patty requires Patty active).
	passive.set_active_sister(thompson, "Liz", context)

	# If Transform is currently active, flip the wielder's sister to Patty by
	# re-applying the wielder package with the new sister. refresh=true on the
	# existing effects handles the in-place replacement. Death the Kid is a
	# special case — he already wields both sisters, so flipping is a no-op.
	var wielder = _find_current_wielder(thompson)
	if wielder != null and wielder.path_name != "kid":
		transform.apply_wielder_package(thompson, wielder, "Patty", -1, context)

func _find_current_wielder(thompson):
	for ch in thompson.battle.all_characters():
		if ch.has_effect("Transform: Demon Twin Guns", EffectType.Type.MARK, thompson) != null:
			return ch
	return null

func extra_usable(user):
	var active = user.has_effect("Brooklyn Devils", EffectType.Type.MARK, user)
	return active != null and active.mag == 1

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
