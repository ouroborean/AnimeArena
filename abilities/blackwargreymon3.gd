extends Ability

func describe(user):
	return "Removes all Shield and Nullify effects from all characters on the field, then deals 35 damage to target enemy. Damage is increased by 5 for each Shield and Nullify effect removed."

func split_desc():
	return [
		["Removes all Shield and Nullify effects from every character on the field", Color.ORANGE_RED],
		"Deals 35 damage to target enemy",
		["+5 damage for each Shield or Nullify effect removed", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var removed = 0
	# Remove Shield (SHIELD) and Nullify (BARRIER) the VALID way. shatter_shields / shatter_barrier fire
	# each effect's wrapup_func + check_effect_breaking — the same teardown natural damage uses — so
	# effects CONTINGENT on a shield (Alphamon's damage-tick companion, Ichigo's Hollow revert, Chrome/
	# Orihime/Jupiter companions, etc.) clean up instead of leaking. Raw erase_effect skips those hooks.
	# Count effects up front (describe promises +5 damage per Shield/Nullify effect removed); the copies
	# returned by get_*_effects() make the count-then-shatter order safe.
	for c in battle.all_characters():
		removed += c.get_shield_effects().size()
		c.shatter_shields(user)
		removed += c.get_barrier_effects().size()
		c.shatter_barrier(user)
	var dmg = 35 + 5 * removed
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, dmg, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
