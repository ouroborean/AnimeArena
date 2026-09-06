extends Ability

# Special Beam Cannon (display slot 0). A CHANNELING skill: first use begins Channeling (+1 stack at
# the end of each turn); RE-USING it fires the payoff — 25 Piercing to the target, +25 per stack.
#
# Carries "Preserves Channel" (like all of Piccolo's actives) so using it does NOT route through
# cancel_channels(): each channel skill manages the channel itself in execute(). See piccolo5 (Namekian
# Power) for the shared end-of-channel logic and the owner-confirmed lifecycle.

const BASE = 25
const PER_STACK = 20

func describe(user):
	return ""

func split_desc():
	return [
		"Piccolo begins Channeling, gaining 1 stack of Special Beam Cannon at the end of each turn",
		["Re-use this skill to deal 25 Piercing damage to target enemy, +20 per stack of Special Beam Cannon on him", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var passive = user.moveset.base_abilities[4]
	var mine = user.has_effect(ability_name, EffectType.Type.CHANNEL_CANCEL, user)
	if mine != null:
		# RE-USE -> fire payoff (scaled by current stacks), then finish the channel (shield + CD + teardown).
		_payoff(user, context, _stacks(user))
		passive.finish_channel(user, mine, "reuse")
		return
	# Starting a channel while ALREADY channeling something else ends that one first (shield + CD, no payoff).
	for m in user.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL):
		passive.finish_channel(user, m, "switch")
	_start_channel(user, context)

func _stacks(user) -> int:
	var e = user.has_effect(ability_name, EffectType.Type.MARK, user)
	return e.stack_count() if e else 0

func _payoff(user, context, stacks):
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, BASE + PER_STACK * stacks, DamageType.Type.PIERCING)

# Install the channel: a stack MARK on Piccolo (starts at 0) + an END_OF_TURN_TRIGGER that adds +1 at
# the end of PICCOLO'S turn — NOT a ticking effect: ticks can be re-ordered to steal an extra stack on
# the re-use turn, whereas an end-of-turn trigger is torn down by the re-use's teardown before it can
# fire. Plus the CHANNEL_CANCEL master (mag = turns channeled; wrapup = enemy-interrupt).
func _start_channel(user, context):
	var mark = Effect.mark(-1, func(eff): return "Special Beam Cannon: " + str(eff.stack_count()) + " stack(s).")
	mark.stackable = true
	mark.display_stacks = true
	mark.stacks = 0
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

	var tick = Effect.trigger_effect(Trigger.always(sbc_tick), EffectType.Type.END_OF_TURN_TRIGGER, -1, "Channeling Special Beam Cannon: +1 stack at the end of Piccolo's turn.")
	tick.set_source(self)
	Character.add_allied_effect(context, user, user, tick)

	var master = Effect.channel_cancel(-1, ability_name, [tick, mark])
	master.set_source(self)
	master.mag = 0   # turns spent channeling; +1 at each end of Piccolo's turn
	master.wrapup_func = user.moveset.base_abilities[4].on_interrupt
	Character.add_allied_effect(context, user, user, master)

func sbc_tick(context):
	var piccolo = context['effect'].user
	if piccolo == null or piccolo.dead or piccolo.banished:
		return
	var mark = piccolo.has_effect(ability_name, EffectType.Type.MARK, piccolo)
	if mark != null:
		mark.stacks += 1
	var master = piccolo.has_effect(ability_name, EffectType.Type.CHANNEL_CANCEL, piccolo)
	if master != null:
		master.mag += 1

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 40)

func target(user, battle):
	# First use (begin Channeling) targets Piccolo himself; re-using it (the payoff) targets one enemy.
	if user.has_effect(ability_name, EffectType.Type.CHANNEL_CANCEL, user) != null:
		default_hostile_target_function(user, battle)
	else:
		default_self_target_function(user, battle)
