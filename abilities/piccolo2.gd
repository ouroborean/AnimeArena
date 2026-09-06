extends Ability

# Hellzone Grenade (display slot 1). Channel: places 1 stack on ALL targetable enemies at the end of
# each turn; RE-USE for 1 Random -> 10 damage to each enemy per stack ON THAT enemy. Same channel
# machinery as Special Beam Cannon, except the stacks live on the enemies (per-target). The enemy marks
# are appended to the master's cancel_effects so BOTH teardown paths (voluntary + enemy-interrupt) clear
# them. Carries "Preserves Channel".

const PER_STACK = 10

func describe(user):
	return ""

func split_desc():
	return [
		"Piccolo begins Channeling, placing 1 stack of Hellzone Grenade on all targetable enemies at the end of each turn",
		["Re-use this skill for 1 Random to deal 10 damage to all enemies for each stack of Hellzone Grenade on them", Color.ORANGE_RED]
	]

# Re-using THIS skill (the AoE payoff) costs 1 Random; the printed 1 Green is the START cost.
func cost():
	var output = super.cost()
	if user != null and user.has_effect(ability_name, EffectType.Type.CHANNEL_CANCEL, user):
		return {0: 0, 1: 0, 2: 0, 3: 0, 4: 1}
	return output

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var passive = user.moveset.base_abilities[4]
	var mine = user.has_effect(ability_name, EffectType.Type.CHANNEL_CANCEL, user)
	if mine != null:
		_payoff(user, context)
		passive.finish_channel(user, mine, "reuse")
		return
	for m in user.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL):
		passive.finish_channel(user, m, "switch")
	_start_channel(user, context)

func _enemies(user) -> Array:
	# "targetable enemies" — exclude the Invulnerable. Hellzone is NOT a Bypassing skill, and
	# resolve_damage does not itself gate on INVULN (invuln is enforced at targeting), so the payoff
	# would otherwise damage an invulnerable enemy; likewise the end-of-turn tick would keep stacking
	# on an untargetable one. is_invuln(self) is the same per-target check the engine's invuln target
	# drop uses (a class-filtered invuln that doesn't cover this skill still counts as targetable).
	var out = []
	for c in user.battle.all_characters():
		if user.is_hostile(c) and not (c.dead or c.banished) and not c.is_invuln(self):
			out.append(c)
	return out

func _payoff(user, context):
	for enemy in _enemies(user):
		var mark = enemy.has_effect(ability_name, EffectType.Type.MARK, user)
		var stacks = mark.stack_count() if mark else 0
		if stacks > 0:
			Character.resolve_damage(context, enemy, PER_STACK * stacks, DamageType.Type.NORMAL)

# +1 Hellzone stack on `enemy` (creating the mark if new). New marks join the master's cancel_effects so
# they are torn down with the channel. add_hostile_effect drops the mark on an untargetable (Invuln)
# enemy, which is exactly the "targetable enemies" restriction.
func _add_stack(user, context, enemy, master):
	var mark = enemy.has_effect(ability_name, EffectType.Type.MARK, user)
	if mark != null:
		mark.stacks += 1
		return
	mark = Effect.mark(-1, func(eff): return "Hellzone Grenade: " + str(eff.stack_count()) + " stack(s).")
	mark.stackable = true
	mark.display_stacks = true
	mark.stacks = 1
	mark.set_source(self)
	Character.add_hostile_effect(context, user, enemy, mark)
	if master != null and is_instance_valid(master) and not mark.removed:
		master.cancel_effects.append(mark)

func _start_channel(user, context):
	# END_OF_TURN_TRIGGER (not a tick): +1 stack on every targetable enemy at the end of Piccolo's turn.
	# No stacks are placed at start — the first batch lands at the end of this same turn.
	var tick = Effect.trigger_effect(Trigger.always(hellzone_tick), EffectType.Type.END_OF_TURN_TRIGGER, -1, "Channeling Hellzone Grenade: +1 stack on all targetable enemies at the end of Piccolo's turn.")
	tick.set_source(self)

	var master = Effect.channel_cancel(-1, ability_name, [tick])
	master.set_source(self)
	master.mag = 0
	master.wrapup_func = user.moveset.base_abilities[4].on_interrupt
	Character.add_allied_effect(context, user, user, master)
	Character.add_allied_effect(context, user, user, tick)

func hellzone_tick(context):
	var piccolo = context['effect'].user
	if piccolo == null or piccolo.dead or piccolo.banished:
		return
	var master = piccolo.has_effect(ability_name, EffectType.Type.CHANNEL_CANCEL, piccolo)
	if master != null:
		master.mag += 1
	var ctx = QueryContext.from_game_state(piccolo, piccolo.battle)
	for enemy in _enemies(piccolo):
		_add_stack(piccolo, ctx, enemy, master)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 30)

func target(user, battle):
	default_hostile_target_function(user, battle)
