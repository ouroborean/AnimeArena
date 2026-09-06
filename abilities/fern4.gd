extends Ability
var shield_amount = 20

# Protective Barrier. Cheap, no cooldown, and it rewards doubling up: the first cast on someone is
# a one-turn buffer, but any cast onto an already-shielded ally sticks permanently. Stacking it on
# one target is Fern's way of building a wall that survives the whole match.
#
# SHIELD MERGE TRAP: Effect.shield_effect defaults stackable = stack_mag = TRUE, so two shields
# sharing a name and source MERGE — summing the magnitudes and keeping the FIRST one's duration.
# That would silently convert a permanent barrier into a 1-turn one (or vice versa) depending on
# cast order. Both variants are therefore built NON-stackable, which sends effect_storage's
# add_effect down its "store a duplicate" branch: each barrier stays a separate effect with its own
# duration, and the damage loop drains them one after another.

func describe(user):
	return "Target ally gains 20 Shield for 1 turn. If the target already has any Shield, this new 20 Shield is permanent instead."

func split_desc():
	return [
		"Target ally gains 20 Shield for 1 turn",
		["If that ally already has any Shield, the new 20 Shield is permanent instead", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Read BEFORE applying, or the barrier would see itself and always be permanent. Any shield
		# counts, including one an ally put there — get_shield_effects returns only live SHIELD
		# effects, and a depleted one is consumed out of storage, so there is no zombie-at-0 case.
		var already_shielded: bool = not target.get_shield_effects().is_empty()
		var barrier = Effect.shield_effect(shield_amount, -1 if already_shielded else 2)
		barrier.stackable = false
		if already_shielded:
			# A distinct name so the permanent one is legible next to a temporary one, and so the
			# two can never be confused by a name lookup.
			barrier.name_override = "Protective Barrier (Lasting)"
		apply_allied(context, target, barrier)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	for ally in context['ally_team'].characters:
		if ally.dead or ally.banished:
			continue
		# Worth much more on someone already shielded, because that is what makes it stick.
		var bonus: int = 40 if not ally.get_shield_effects().is_empty() else 0
		variations.append([20 + bonus + int((100 - ally.health.hp) * 0.3), [user, self, [ally]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
