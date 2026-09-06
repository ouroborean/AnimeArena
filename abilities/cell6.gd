extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Each turn, deals 10 damage to 3 random targets. Continues as long as Cell continues to Channel."

func split_desc():
	return [
		"Each turn, deals 10 Energy damage to 3 random enemies",
		["Channeled — ends if Cell uses another skill or is stunned", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# The damage-per-turn engine for Rampant Energy Rain. The TICKING_TRIGGER
	# fires once per turn-tick; the callback picks 3 random hostile per fire.
	# channel=true so cancel_channels() removes it cleanly when Cell uses
	# another skill or is stunned.
	var cancels = []
	var dmg_trigger = Effect.trigger_effect(
		Trigger.always(rain_tick),
		EffectType.Type.TICKING_TRIGGER,
		-1,
		"Each turn, Cell hits 3 random enemies for 10 Energy damage."
	)
	dmg_trigger.set_source(self)
	dmg_trigger.channel = true
	cancels.append(dmg_trigger)
	Character.add_allied_effect(context, user, user, dmg_trigger)

	var cancel_master = Effect.channel_cancel(-1, ability_name, cancels)
	cancel_master.set_source(self)
	Character.add_allied_effect(context, user, user, cancel_master)

	# Fire once immediately so the cast turn gets the burst too — otherwise the
	# player pays 1 Blue + 1 Random for a guaranteed-cancelled-next-turn
	# effect, since any skill they use on turn N+1 will break the channel.
	context['effect'] = dmg_trigger
	rain_tick(context)

func rain_tick(context):
	var cell = context.owner
	if cell == null or cell.dead or cell.banished:
		return
	var pool = []
	for i in range(3):
		for c in cell.battle.all_characters():
			if cell.is_hostile(c) and not (c.dead or c.banished):
				pool.append(c)
		var pick = null

		if len(pool) == 0:
			break
		var idx = cell.battle.roll(0, len(pool) - 1)
		pick = pool[idx]
	
		Character.resolve_effect_damage(context, context['effect'], pick, 10, DamageType.Type.ENERGY)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 60)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
