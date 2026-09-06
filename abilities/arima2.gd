extends Ability

# Narukami Blast (Channeled, Bypassing, Uncounterable). Permanently targets one enemy: while the channel
# holds, each time that enemy uses a new skill Arima destroys their Shield and deals 20 damage (+5 per
# Narukami Charge stack from Narukami Sword, consumed into this channel at cast). Being a normal channel
# (NOT Preserves Channel), it auto-ends when Arima uses another skill or is stunned/sealed — which tears
# down the enemy-side watcher automatically because it lives in the channel's cancel list.

func describe(user):
	return "Arima permanently targets one enemy. Whenever that enemy uses a new skill, Arima destroys their Shield and deals 20 damage to them, increased by 5 per stack of Narukami Charge."

func split_desc():
	return [
		"Arima permanently targets one enemy (Channeled)",
		["Whenever the target uses a new skill, Arima destroys their Shield and deals 20 damage", Color.ORANGE_RED],
		["Deals 5 more per stack of Narukami Charge from Narukami Sword", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var target = user.targeter.main_target
	# Consume the Narukami Charge (+5 each) into this channel's reactive damage.
	var bonus = 0
	var charge = user.has_effect("Narukami Charge", EffectType.Type.MARK, user)
	if charge != null:
		bonus = 5 * charge.stack_count()
		user.effects.erase_effect(charge)
	var cancels = []
	var watch = Effect.trigger_effect(Trigger.always(blast_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, func(eff): return "Using a new skill destroys this character's Shield and deals them " + str(20 + int(eff.storage.get("bonus", 0))) + " damage.")
	watch.set_source(self)
	watch.waiting = false
	watch.bypassing = true
	watch.storage["bonus"] = bonus
	cancels.append(watch)
	Character.add_hostile_effect(context, user, target, watch, true)   # bypass invuln to plant the watcher
	# "Ignore negative non-damage while channeling" (SSS Ukaku Quinque): present iff a channel is up. Visible
	# (display_system) so it doubles as the warning that Arima shrugs non-damage effects while channeling.
	var ignore = Effect.ignore_non_damage_effect(-1)
	ignore.description = func(eff): return "This character is ignoring negative non-damage effects while channeling."
	ignore.set_source(user.moveset.base_abilities[4])
	ignore.system = true
	ignore.display_system = true
	cancels.append(ignore)
	Character.add_allied_effect(context, user, user, ignore)
	var master = Effect.channel_cancel(-1, ability_name, cancels)
	master.set_source(self)
	# The riders (esp. the enemy-side watcher) live in `cancels` and are normally torn down by
	# check_cancels/cancel_channels -> _end_cancel_effects. A cleanse/buff-strip removes the master directly
	# (end_effect, NOT check_cancels), which would strand the enemy watcher (it keeps firing forever). Run the
	# same teardown from the master's own wrapup so ANY removal path (cleanse included) ends the riders.
	master.wrapup_func = func(_ctx): user._end_cancel_effects(master)
	Character.add_allied_effect(context, user, user, master)

func blast_trigger(context):
	var foe = context['owner']
	var eff = context['effect']
	var arima = eff.user
	if arima == null or arima.dead or arima.banished:
		return
	if foe == null or foe.dead or foe.banished:
		return
	foe.shatter_shields(arima)
	Character.resolve_effect_damage(context, eff, foe, 20 + int(eff.storage.get("bonus", 0)), DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, true)   # Bypassing: can target through Invulnerability
