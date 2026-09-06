extends Ability


func describe(user):
	return "Itachi targets an enemy or an ally for 1 turn. If an ally, counters the next Harmful skill used on them. If an enemy, counters the next Harmful skill they use. The target of this skill is invisible."


func split_desc():
	return [
		"For 2 turns, the target is marked (Invisible)",
		"If allied: counters the next Harmful skill used on them",
		"If hostile: counters the next Harmful skill they use",
	]


func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		if user.is_hostile(target):
			var counter = Effect.counter_effect(
				Trigger.always(kotoamatsukami_countered),
				EffectType.Type.COUNTER_USE,
				4,   # 2 turns: durations tick at the end of EVERY player's turn
				"The next Harmful skill this character uses will be countered.",
				["Harmful"])
			counter.wrapup_func = default_counter_timeout
			counter.invisible = true
			apply_hostile(context, target, counter)
		else:
			var counter = Effect.counter_effect(
				Trigger.always(kotoamatsukami_countered),
				EffectType.Type.COUNTER_RECEIVE,
				4,   # 2 turns — must stay in lockstep with the hostile branch above
				"The next Harmful skill used on this character will be countered.",
				["Harmful"])
			counter.wrapup_func = default_counter_timeout
			counter.invisible = true
			apply_allied(context, target, counter)


# Shared callback for both COUNTER_USE (cast on enemy) and COUNTER_RECEIVE
# (cast on ally). In both cases context['owner'] is the countered enemy —
# either because they tried to use a Harmful skill (USE), or because they
# tried to use one on the protected ally (RECEIVE). Either way, drop a
# breadcrumb on them so Tsukuyomi can banish next turn.
func kotoamatsukami_countered(context):
	var enemy = context['owner']
	var itachi = context['effect'].user
	if not (itachi.dead or itachi.banished or enemy.dead or enemy.banished):
		var memo = Effect.mark(2, "Kotoamatsukami countered this character last turn.")
		memo.invisible = true
		memo.system = true
		apply_hostile(QueryContext.from_game_state(itachi, itachi.battle), enemy, memo, true)
	default_counter_trigger(context)


func extra_usable(user):
	return true


func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		if not (character.dead or character.banished):
			variations.append([60, [user, self, [character]]])
	for character in context['ally_team'].characters:
		if not (character.dead or character.banished):
			variations.append([40 + (100 - character.health.hp) / 2, [user, self, [character]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations


func target(user, battle):
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
