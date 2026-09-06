extends Ability

# Burning Wrath Whirl. Channeled AOE Affliction DoT: 10 Affliction to all enemies each turn while
# Tsubasa keeps channeling. On the final (3rd) tick it swaps in Burning Wrath Blade for 1 turn.
# Self-hosted TICKING_TRIGGER + channel_cancel (cell6 pattern); manual first instance on the cast turn.

const TOTAL_TICKS = 3

func describe(user):
	return "Channeled. Deals 10 Affliction damage to all enemies each turn for 3 turns, and on the first turn also stuns all enemies' non-Strategic skills for 1 turn. On the final turn it replaces this skill with Burning Wrath Blade for 1 turn. Channeling ends early if Tsubasa is stunned or uses another skill (no Blade)."

func split_desc():
	return [
		"Each turn, deals 10 Affliction damage to all enemies",
		["On the first turn, also stuns all enemies' non-Strategic skills for 1 turn", Color.CADET_BLUE],
		["Channeled — ends if Tsubasa is stunned or uses another skill", Color.DIM_GRAY],
		["On its final tick, swaps in Burning Wrath Blade for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var cancels = []
	var dmg_trigger = Effect.trigger_effect(Trigger.always(wrath_tick), EffectType.Type.TICKING_TRIGGER, 2 * TOTAL_TICKS - 1, "Each turn, Tsubasa hits all enemies for 10 Affliction damage.")
	dmg_trigger.set_source(self)
	dmg_trigger.channel = true
	dmg_trigger.mag = 0
	cancels.append(dmg_trigger)
	Character.add_allied_effect(context, user, user, dmg_trigger)

	var cancel_master = Effect.channel_cancel(2 * TOTAL_TICKS - 1, ability_name, cancels)
	cancel_master.set_source(self)
	Character.add_allied_effect(context, user, user, cancel_master)

	# Fire once immediately so the cast turn deals the first AOE tick (cell6 idiom).
	context['effect'] = dmg_trigger
	wrath_tick(context)

	# The cast turn ALSO stuns every enemy's non-Strategic skills for 1 turn. Applied by hand here for
	# the same reason as the first damage tick: a TICKING effect never fires on the turn it is applied,
	# so the opening stun would otherwise never land. (dur 2 = 1 turn; exclude Strategic => non-Strategic.)
	for c in user.battle.all_characters():
		if user.is_hostile(c) and not (c.dead or c.banished):
			var stun = Effect.stun_effect(2, [], ["Strategic"])
			stun.set_source(self)
			Character.add_hostile_effect(context, user, c, stun)

func wrath_tick(context):
	var tsubasa = context.owner
	if tsubasa == null or tsubasa.dead or tsubasa.banished:
		return
	var eff = context['effect']
	eff.mag += 1
	for c in tsubasa.battle.all_characters():
		if tsubasa.is_hostile(c) and not (c.dead or c.banished):
			Character.resolve_effect_damage(context, eff, c, 10, DamageType.Type.AFFLICTION)
	# Final tick -> swap this skill for Burning Wrath Blade (base_abilities[5]) into slot 2 for 1 turn.
	if eff.mag >= TOTAL_TICKS:
		var swap_ctx = QueryContext.from_game_state(tsubasa, tsubasa.battle)
		var swap = Effect.ability_swap_effect(5, 2, tsubasa, 3)
		swap.set_source(self)
		Character.add_allied_effect(swap_ctx, tsubasa, tsubasa, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
