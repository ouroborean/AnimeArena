extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Target enemy gains 25 Nullify and receives 15 Affliction damage per turn for 2 turns. If the target has 30 or less HP, they are also Stunned for 1 turn."

func split_desc():
	return [
		"Target enemy gains 25 Nullify (Barrier blocking their outgoing damage) for 2 turns",
		"Target receives 15 Affliction damage per turn for 2 turns",
		["If the target has 30 or less HP, they are also Stunned for 1 turn", Color.CADET_BLUE],
		["Triggers Genetic Perfection if the enemy dies or fails to break the Nullify", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Anchor mark — single source of truth for "Absorption is active on this
		# target." Both transformation trigger paths check this before firing,
		# and the path that fires removes it, preventing double-trigger from the
		# same cast. system=true so it survives the post-death cleanse window long
		# enough for ON_DEATH_TRIGGER to read it.
		var anchor = Effect.mark(3, "This character is under Cell's Absorption.")
		anchor.set_source(self)
		anchor.system = true
		anchor.invisible = true
		Character.add_hostile_effect(context, user, target, anchor)

		# Nullify (Barrier) — absorbs the holder's OUTGOING damage. Its wrap_up
		# only fires when end_effect(CANCELLED) is invoked, which happens on
		# natural duration expiry but NOT on consume_effect (which is called
		# when the barrier is fully depleted by outgoing damage). So a wrap_up
		# call here is exactly "barrier expired without being broken."
		var nullify = Effect.barrier_effect(25, 3)
		nullify.set_source(self)
		nullify.wrapup_func = nullify_expired_callback
		Character.add_hostile_effect(context, user, target, nullify)

		# Affliction DOT.
		var dot = Effect.damage_effect(15, DamageType.Type.AFFLICTION, 3)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)

		# Death watcher. Sourced from this ability so its effect_name is also
		# "Absorption" and lives/dies alongside the rest of the package.
		var death_watcher = Effect.trigger_effect(
			Trigger.always(death_trigger),
			EffectType.Type.ON_DEATH_TRIGGER,
			5,
			""
		)
		death_watcher.set_source(self)
		death_watcher.system = true
		death_watcher.invisible = true
		Character.add_hostile_effect(context, user, target, death_watcher)
		Character.resolve_damage(context, target, 15, DamageType.Type.AFFLICTION)
		# Execute condition: stun if low HP. Snapshot HP before the DOT
		# resolves (the DOT itself doesn't tick on the cast turn anyway).
		if target.health.hp <= 30:
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)

func nullify_expired_callback(context):
	# This wrap_up fires on BOTH natural duration expiry AND being broken — check_effect_breaking
	# calls wrapup_func when an attack depletes the barrier (setting .breaker to the attacker first).
	# Only "expired unbroken" transforms Cell, so bail when the barrier was broken.
	if context.effect != null and context.effect.breaker != null:
		return
	# Barrier ticked to 0 by duration — target failed to break it. Convert
	# this into a Genetic Perfection trigger if the Absorption package is
	# still active on the target.
	var cell = context.owner
	var target = context.target
	if cell == null or target == null:
		return
	if cell.dead or cell.banished:
		return
	var passive = cell.moveset.base_abilities[4]
	passive.attempt_transformation(context, cell)

func death_trigger(context):
	var target = context.target
	var cell = context.owner
	if target == null or cell == null:
		return
	if cell.dead or cell.banished:
		return
	var passive = cell.moveset.base_abilities[4]
	passive.attempt_transformation(context, cell)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 60)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
