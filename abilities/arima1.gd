extends Ability

# Narukami Sword. A normal skill — casting it cancels any active channel like any other non-channel
# skill. It only INTERACTS with its partner: if the channel it just interrupted was Narukami Blast, Arima
# gains 15 Shield (read from last_cancelled_channels, populated by cancel_channels right before execute).
# Also primes +5 to Arima's next Narukami Blast (a stacking Narukami Charge).

func describe(user):
	return "Deals 15 damage to target enemy and increases the damage of Arima's next Narukami Blast by 5. If this skill cancels an active Narukami Blast, Arima also gains 15 Shield."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["Increases the damage of Arima's next Narukami Blast by 5 (stacks)", Color.CADET_BLUE],
		["If it cancels an active Narukami Blast, Arima gains 15 Shield", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
	# Prime +5 to the next Narukami Blast (stacking).
	var charge = Effect.mark(-1, func(eff): return "Arima's next Narukami Blast deals " + str(5 * eff.stack_count()) + " more damage.")
	charge.name_override = "Narukami Charge"
	charge.stackable = true
	charge.display_stacks = true
	charge.set_source(self)
	Character.add_allied_effect(context, user, user, charge)
	# +15 Shield if casting this skill just interrupted an active Narukami Blast channel.
	if "Narukami Blast" in user.last_cancelled_channels:
		var sh = Effect.shield_effect(15, -1)
		sh.set_source(self)
		Character.add_allied_effect(context, user, user, sh)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 15)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
