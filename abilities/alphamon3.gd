extends Ability

func describe(user):
	return "Permanently gives Alphamon 15 Shield and all enemies 10 Nullify. Each turn an enemy has Nullify from this skill remaining, Alphamon deals 10 damage to them. Each turn Alphamon has Shield from this skill remaining, he deals 10 damage to all enemies."

func split_desc():
	return [
		"Permanently gives Alphamon 15 Shield. While active, deals 10 damage to all enemies each turn.",
		"Permanently gives all enemies 10 Nullify. While the Nullify remains on an enemy, Alphamon deals 10 damage to them each turn.",
	]

func execute(user, battle):
	var context = make_context(battle)

	if user.has_effect("Digitalize of Soul", EffectType.Type.SHIELD, user) == null:
		var shield = Effect.shield_effect(15, -1)
		shield.set_source(self)
		shield.wrapup_func = shield_ending
		Character.add_allied_effect(context, user, user, shield)

	var fresh_shield_tick = null
	if user.has_effect("Digitalize of Soul", EffectType.Type.TICKING_TRIGGER, user) == null:
		var shield_tick = Effect.trigger_effect(
			Trigger.always(shield_tick_payload),
			EffectType.Type.TICKING_TRIGGER,
			-1,
			"Alphamon deals 10 damage to all enemies each turn while Digitalize of Soul Shield remains.")
		shield_tick.set_source(self)
		Character.add_allied_effect(context, user, user, shield_tick)
		fresh_shield_tick = shield_tick

	var fresh_nullify_ticks = []
	for target in user.targeter.targets:
		if target == user:
			continue
		if not user.is_hostile(target):
			continue
		if target.dead or target.banished:
			continue

		if target.has_effect("Digitalize of Soul", EffectType.Type.BARRIER, user) == null:
			var nullify = Effect.barrier_effect(10, -1)
			nullify.set_source(self)
			nullify.remove_on_death = true
			nullify.wrapup_func = nullify_ending
			Character.add_hostile_effect(context, user, target, nullify)

		if target.has_effect("Digitalize of Soul", EffectType.Type.TICKING_TRIGGER, user) == null:
			var nullify_tick = Effect.trigger_effect(
				Trigger.always(nullify_tick_payload),
				EffectType.Type.TICKING_TRIGGER,
				-1,
				"Alphamon deals 10 damage to this enemy each turn while Digitalize of Soul Nullify remains.")
			nullify_tick.set_source(self)
			nullify_tick.damage_type = DamageType.Type.NORMAL
			nullify_tick.cleansable = true
			nullify_tick.remove_on_death = true
			Character.add_hostile_effect(context, user, target, nullify_tick)
			fresh_nullify_ticks.append(nullify_tick)

	# Ticking effects don't tick on the turn they're applied. Manually fire one tick now for any
	# trigger we just installed so the cast turn matches subsequent turns.
	if fresh_shield_tick != null:
		shield_tick_payload(QueryContext.from_effect_end(fresh_shield_tick))
	for tick in fresh_nullify_ticks:
		nullify_tick_payload(QueryContext.from_effect_end(tick))

func shield_tick_payload(context):
	var eff = context['effect']
	var alphamon = eff.user
	if alphamon == null or alphamon.dead or alphamon.banished:
		return
	if alphamon.has_effect("Digitalize of Soul", EffectType.Type.SHIELD, alphamon) == null:
		alphamon.effects.erase_effect(eff)
		return
	for enemy in alphamon.battle.all_characters():
		if not alphamon.is_hostile(enemy):
			continue
		if enemy.dead or enemy.banished:
			continue
		Character.resolve_effect_damage(context, eff, enemy, 10, DamageType.Type.NORMAL)

func nullify_tick_payload(context):
	var eff = context['effect']
	var enemy = eff.target
	var alphamon = eff.user
	if enemy == null or enemy.dead or enemy.banished:
		return
	if alphamon == null or alphamon.dead or alphamon.banished:
		enemy.effects.erase_effect(eff)
		return
	if enemy.has_effect("Digitalize of Soul", EffectType.Type.BARRIER, alphamon) == null:
		enemy.effects.erase_effect(eff)
		return
	Character.resolve_effect_damage(context, eff, enemy, 10, DamageType.Type.NORMAL)

func shield_ending(context):
	var ended_eff = context['source']
	var alphamon = ended_eff.user
	if alphamon == null:
		return
	var tick = alphamon.has_effect("Digitalize of Soul", EffectType.Type.TICKING_TRIGGER, alphamon)
	if tick != null:
		alphamon.effects.erase_effect(tick)

func nullify_ending(context):
	var ended_eff = context['source']
	var enemy = ended_eff.target
	var alphamon = ended_eff.user
	if enemy == null or alphamon == null:
		return
	var tick = enemy.has_effect("Digitalize of Soul", EffectType.Type.TICKING_TRIGGER, alphamon)
	if tick != null:
		enemy.effects.erase_effect(tick)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 10)

func target(user, battle):
	default_hostile_target_function(user, battle)
