extends Ability

# Tiger King (cooldown 0). Stuns the target's Strategic skills for a turn and arms a delayed strike. On
# Baki's following turn it lands 25 damage — UNLESS Baki has taken non-Affliction damage in the meantime,
# which cancels the strike AND puts Tiger King on a 1-turn cooldown as a penalty.
#
# Each cast's delayed strike carries its OWN cancelled flag in `storage` (so overlapping casts — possible
# because the base cooldown is 0 — can't cross-contaminate). A single shared, permanent, non-cleansable
# DAMAGE_RECEIVE_TRIGGER on Baki cancels every pending strike the moment he takes a non-Affliction hit:
# it ERASES the pending-strike effect (so its tooltip disappears immediately rather than lingering and
# resolving to nothing) and applies the 1-turn cooldown — only when it actually cancels a pending strike.

func describe(user):
	return "Stuns target enemy's Strategic skills for 1 turn. On the following turn, that enemy takes 25 damage. If Baki receives non-Affliction damage before then, that enemy takes no damage and Tiger King's cooldown is set to 1."

func split_desc():
	return [
		"Stuns the target's Strategic skills for 1 turn",
		["Next turn, deals 25 damage to the target", Color.ORANGE_RED],
		["If Baki takes non-Affliction damage before then, the target takes no damage and this skill's cooldown is set to 1", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(2, ["Strategic"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		# Delayed strike; its cancelled state is per-cast, and it is non-cleansable so only a non-Affliction
		# hit on Baki (not a buff-strip) can cancel it.
		var tick = Effect.trigger_effect(Trigger.always(delayed_strike), EffectType.Type.TICKING_TRIGGER, 3, "This character will take 25 damage.")
		tick.set_source(self)
		tick.last_turn_only = true
		tick.cleansable = false
		tick.damage_type = DamageType.Type.NORMAL   # effectively a delayed hit — not dropped by ignore-non-damage / Ainz's negate
		tick.storage["cancelled"] = false
		Character.add_hostile_effect(context, user, target, tick)
	# One shared watcher on Baki (permanent machinery): a non-Affliction hit cancels every pending strike.
	if user.has_effect(ability_name, EffectType.Type.DAMAGE_RECEIVE_TRIGGER, user) == null:
		var watcher = Effect.trigger_effect(Trigger.always(cancel_on_damage), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "If Baki takes non-Affliction damage, his pending Tiger King strikes are cancelled.")
		watcher.set_source(self)
		watcher.waiting = false
		watcher.invisible = true
		watcher.cleansable = false
		watcher.system = true
		watcher.remove_on_death = false
		Character.add_allied_effect(context, user, user, watcher)

func cancel_on_damage(context):
	# Affliction damage does NOT cancel; anything else cancels every pending strike.
	if context.damage_type == DamageType.Type.AFFLICTION:
		return
	var baki = context.effect.user
	if baki == null or not is_instance_valid(baki) or baki.battle == null:
		return
	var cancelled_any = false
	for enemy in baki.battle.all_characters():
		# Collect first, then erase — mutating _effects while iterating get_effects_by_type is unsafe.
		var to_cancel = []
		for e in enemy.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER):
			if e.user == baki and e.source == self and not e.storage.get("cancelled", false):
				to_cancel.append(e)
		for e in to_cancel:
			# REMOVE the pending strike so its tooltip disappears immediately — a cancelled strike used to
			# linger on the target and resolve to nothing on its fire turn. The cancelled flag stays as a
			# same-turn safety net: if the damage lands after this turn's ticking batch was already
			# snapshotted, delayed_strike still sees cancelled and no-ops.
			e.storage["cancelled"] = true
			enemy.effects.erase_effect(e)
			cancelled_any = true
	# Penalty for interrupting Tiger King: put it on a 1-turn cooldown — but only when a pending strike
	# was actually cancelled (taking damage with nothing pending must not lock the skill). Set on the
	# enemy's turn, this survives to Baki's next turn (advance_cooldowns only ticks the acting team).
	if cancelled_any:
		cooldown_remaining = 1

func delayed_strike(context):
	var eff = context.effect
	var target = context.target
	var baki = eff.user
	if baki == null or baki.dead or baki.banished:
		return
	if eff.storage.get("cancelled", false):
		return
	if not (target.dead or target.banished):
		Character.resolve_effect_damage(context, eff, target, 25, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 25)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
