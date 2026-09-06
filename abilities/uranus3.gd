extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 10 damage to all enemies for 3 turns. During this time, affected enemies receive 5 more damage from the ally marked by Uranus Lip Rod."

func split_desc():
	return [
		"Deals 10 Energy damage to all enemies, then 10 each turn for 2 more turns",
		["Affected enemies take +5 damage from the ally marked by Uranus Lip Rod for the duration", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Manual first-tick damage (the DOT below doesn't tick on its cast
		# turn). The Energy damage_type matches the ability's Energy class.
		Character.resolve_damage(context, target, 10, DamageType.Type.ENERGY)
		var dot = Effect.damage_effect(10, DamageType.Type.ENERGY, 5)
		dot.set_source(self)
		dot.action = true
		Character.add_hostile_effect(context, user, target, dot)
		# Tag the target with a "World Shaking" mark so the ally-specific
		# +5 damage boost has a stable per-enemy marker to read. The actual
		# +5 boost wiring is intentionally NOT implemented here — that's
		# user-handled per the spec for this kit. Whatever observer ends up
		# applying the boost can check `target.marked_by("World Shaking", user)`
		# (user = Uranus, source = this ability).
		var mark = Effect.mark(5, "Takes +5 damage from the ally marked by Uranus Lip Rod.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 60)
	return variations

func target(user, battle):
	# target_type=ALL with class restriction to enemies is handled by the
	# engine — default_hostile_target_function picks up the enemy faction.
	default_hostile_target_function(user, battle)
