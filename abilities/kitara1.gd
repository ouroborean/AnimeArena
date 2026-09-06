extends Ability

var base_damage = 10

# Slicing Water Waves. A permanent Channel that opens at 10 Piercing and ramps: every hit that actually
# deals damage adds 5 to the next one for the rest of the Channel. Modelled as a ticking trigger (so it
# can carry its own scaling `mag`) rather than a flat DoT; the channel-cancel machinery ends it the same
# way it ended the old DoT.

func describe(user):
	return "Deals 10 Piercing damage to target enemy permanently. Each time it deals damage, its damage increases by 5 for the rest of the Channel. Channeled — ends if Katara uses another skill or is stunned."

func split_desc():
	return [
		"Deals 10 Piercing damage to target enemy per turn, permanently.",
		["Each hit that deals damage increases its damage by 5 for the rest of the Channel", Color.ORANGE_RED],
		["Ends if Katara uses another skill or is stunned.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var cancels = []
	for target in user.targeter.targets:
		var landed = not target.is_ignoring_damage(true, user)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		# The opening hit counts toward the ramp: if it landed, the next tick is already +5.
		var wave = Effect.trigger_effect(Trigger.always(wave_tick), EffectType.Type.TICKING_TRIGGER, -1,
			"Slicing Water Waves will deal Piercing damage to this character.")
		wave.mag = base_damage + (5 if landed else 0)
		wave.display_mag = true
		wave.channel = true
		wave.set_source(self)
		wave.damage_type = DamageType.Type.PIERCING
		cancels.append(wave)
		Character.add_hostile_effect(context, user, target, wave)
	var cancel_eff = Effect.channel_cancel(-1, ability_name, cancels)
	cancel_eff.set_source(self)
	Character.add_allied_effect(context, user, user, cancel_eff)

func wave_tick(context):
	var eff = context['effect']
	var target = context.target
	if target.dead or target.banished:
		return
	var landed = not target.is_ignoring_damage(false, eff.user)
	Character.resolve_effect_damage(context, eff, target, int(eff.mag), DamageType.Type.PIERCING)
	if landed:
		eff.mag += 5
		eff.effect_updated.emit(eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 45, 1.1)

func target(user, battle):
	default_hostile_target_function(user, battle)
