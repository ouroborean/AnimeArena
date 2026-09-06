extends Ability


func describe(user):
	return "Mavis channels Fairy Law for 3 turns. On the 3rd turn, each enemy that is not Invulnerable takes 35 damage and is stunned for 1 turn, and each ally that is not Isolated heals 25 HP."


func split_desc():
	return [
		"Mavis channels for 3 turns",
		"On resolution: enemies that are not Invulnerable take 35 damage and are stunned for 1 turn",
		"On resolution: allies that are not Isolated heal 25 HP",
		["Cancels if Mavis is stunned", Color.DIM_GRAY],
	]


func execute(user, battle):
	var context = make_context(battle)
	var ticker = Effect.trigger_effect(
		Trigger.always(fairy_law_resolve),
		EffectType.Type.TICKING_TRIGGER,
		5,
		"Fairy Law resolves at the end of the channel.")
	ticker.last_turn_only = true
	apply_allied(context, user, ticker)

	track_cancellable(context, 5, [ticker])


func fairy_law_resolve(context):
	if context['effect'].duration != 1:
		return
	var mavis = context['effect'].user
	var ticker = context['effect']
	var qc = QueryContext.from_game_state(mavis, mavis.battle)

	for c in mavis.battle.all_characters():
		if c.dead or c.banished:
			continue
		if mavis.is_hostile(c):
			if c.is_invuln(self):
				continue
			Character.resolve_effect_damage(qc, ticker, c, 35, DamageType.Type.NORMAL)
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(qc, mavis, c, stun)
		else:
			if c.is_isolated():
				continue
			Character.resolve_effect_healing(qc, ticker, c, 25)


func extra_usable(user):
	return not user.marked_by("Fairy Heart")


func custom_behavior(context):
	return behavior_self_panic_button(context, 60)


func target(user, battle):
	default_self_target_function(user, battle)
