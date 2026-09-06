extends Ability

var tick_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, enemies have their strategic skills delayed for 1 turn and Nightmare Wavelength deals 20 more damage."

func split_desc():
	return [
		["For 3 turns, enemies have their strategic skills delayed for 1 turn", Color.ORANGE_RED],
		["Targets receive 10 Affliction damage each turn", Color.ORANGE_RED],
		["The ally wielding Soul receives 10 Affliction damage each turn", Color.DIM_GRAY],
		["Nightmare Wavelength deals 10 more damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	if user.has_effect("Scythe Transformation", EffectType.Type.PERCENT_DR, user):
		user.manually_advance_mission(10, 1)

	for target in user.targeter.targets:
		var delay_eff = Effect.delay_eff(1, 6, 1, ["Strategic"])
		delay_eff.set_source(self)

		Character.add_hostile_effect(context, user, target, delay_eff)

		# The tick lands on the CAST turn, so the window is one manual instance plus a ticker of
		# duration 2N-1 == 5 for a 3-turn window (a ticking effect never fires the turn it lands).
		Character.resolve_damage(context, target, tick_damage, DamageType.Type.AFFLICTION)
		var dot = Effect.damage_effect(tick_damage, DamageType.Type.AFFLICTION, 5)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)

	# The wielder gets a TICKING_TRIGGER on Soul rather than a DAMAGE effect of its own, because
	# Scythe Transformation can move to a different ally (or lapse) inside this window - the
	# wielder has to be resolved at every tick, not baked in at cast.
	var wielder = find_wielder(user)
	if wielder != null:
		Character.resolve_damage(context, wielder, tick_damage, DamageType.Type.AFFLICTION)
	var wielder_tick = Effect.trigger_effect(
		Trigger.always(wielder_tick_payload), EffectType.Type.TICKING_TRIGGER, 5,
		"The ally wielding Soul will receive 10 Affliction damage each turn."
	)
	wielder_tick.set_source(self)
	wielder_tick.damage_type = DamageType.Type.AFFLICTION
	Character.add_allied_effect(context, user, user, wielder_tick)

	var boost_eff = Effect.mark(5, "Nightmare Wavelength will deal 10 more damage.")
	boost_eff.set_source(self)
	Character.add_allied_effect(context, user, user, boost_eff)

func find_wielder(soul):
	for character in soul.team.characters:
		if character.dead or character.banished:
			continue
		if character.has_effect("Scythe Transformation", EffectType.Type.MARK, soul):
			return character
	return null

func wielder_tick_payload(context):
	var soul = context['effect'].user
	var wielder = find_wielder(soul)
	if wielder == null:
		return
	Character.resolve_effect_damage(
		context, context['effect'], wielder, tick_damage, DamageType.Type.AFFLICTION
	)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 50)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
