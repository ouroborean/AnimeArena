extends Ability

# Regeneration (display slot 2). Channel: +1 stack/turn on Piccolo; RE-USE for FREE -> heal for half his
# missing HP + 10 per stack. Same channel machinery as Special Beam Cannon (piccolo1); shared end logic
# lives on the Namekian Power passive (base_abilities[4]). Carries "Preserves Channel".

const PER_STACK = 10

func describe(user):
	return ""

func split_desc():
	return [
		"Piccolo begins Channeling, gaining 1 stack of Regeneration at the end of each turn",
		["Re-use this skill for no cost to heal for half his missing HP + 10 per stack of Regeneration on him", Color.AQUA]
	]

# Re-using THIS skill (the heal payoff) is free; the printed 1 Green is the START cost.
func cost():
	var output = super.cost()
	if user != null and user.has_effect(ability_name, EffectType.Type.CHANNEL_CANCEL, user):
		return {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	return output

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var passive = user.moveset.base_abilities[4]
	var mine = user.has_effect(ability_name, EffectType.Type.CHANNEL_CANCEL, user)
	if mine != null:
		_payoff(user, context, _stacks(user))
		passive.finish_channel(user, mine, "reuse")
		return
	for m in user.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL):
		passive.finish_channel(user, m, "switch")
	_start_channel(user, context)

func _stacks(user) -> int:
	var e = user.has_effect(ability_name, EffectType.Type.MARK, user)
	return e.stack_count() if e else 0

func _payoff(user, context, stacks):
	var missing = int(user.health.max_hp) - int(user.health.hp)
	var heal = int(missing / 2.0) + PER_STACK * stacks
	Character.resolve_healing(context, user, heal)

func _start_channel(user, context):
	var mark = Effect.mark(-1, func(eff): return "Regeneration: " + str(eff.stack_count()) + " stack(s).")
	mark.stackable = true
	mark.display_stacks = true
	mark.stacks = 0
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

	var tick = Effect.trigger_effect(Trigger.always(regen_tick), EffectType.Type.END_OF_TURN_TRIGGER, -1, "Channeling Regeneration: +1 stack at the end of Piccolo's turn.")
	tick.set_source(self)
	Character.add_allied_effect(context, user, user, tick)

	var master = Effect.channel_cancel(-1, ability_name, [tick, mark])
	master.set_source(self)
	master.mag = 0
	master.wrapup_func = user.moveset.base_abilities[4].on_interrupt
	Character.add_allied_effect(context, user, user, master)

func regen_tick(context):
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
	return behavior_self_panic_button(context, 40)

func target(user, battle):
	default_self_target_function(user, battle)
