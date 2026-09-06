extends Ability

func describe(user):
	return "For 3 turns, Lyserg applies 1 Morphin Mark to a random enemy each turn, and to any enemy that uses a Harmful skill on him. During this time, Homing Pendulum is replaced by Halvaya and Big Ben Wire Frame cannot be used."

func split_desc():
	return [
		"For 3 turns, Lyserg applies 1 Morphin Mark to a random enemy each turn",
		"Also applies 1 Morphin Mark to any enemy that uses a Harmful skill on him",
		["Homing Pendulum is replaced by Halvaya while active", Color.CADET_BLUE],
		["Big Ben Wire Frame cannot be used while active", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var self_mark = Effect.mark(6, "Homing Pendulum is replaced by Halvaya. Big Ben Wire Frame cannot be used.")
	self_mark.set_source(self)
	Character.add_allied_effect(context, user, user, self_mark)

	var swap = Effect.ability_swap_effect(5, 0, user, 6)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

	var tick = Effect.trigger_effect(
		Trigger.always(random_mark_tick),
		EffectType.Type.TICKING_TRIGGER,
		6,
		"Lyserg applies 1 Morphin Mark to a random enemy each turn.")
	tick.set_source(self)
	Character.add_allied_effect(context, user, user, tick)

	var retal = Effect.trigger_effect(
		Trigger.always(retal_mark),
		EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
		6,
		"Any enemy that uses a Harmful skill on Lyserg gains 1 Morphin Mark.")
	retal.set_source(self)
	Character.add_allied_effect(context, user, user, retal)

	_apply_random_mark(context, user)

func _apply_random_mark(context, lyserg):
	if lyserg.dead or lyserg.banished:
		return
	var valid = []
	for ch in lyserg.battle.all_characters():
		if lyserg.is_hostile(ch) and not (ch.dead or ch.banished):
			if not ch.is_invuln(self):
				valid.append(ch)
	if valid.is_empty():
		return
	var chosen = valid[lyserg.battle.roll(0, valid.size() - 1)]
	var caster_kit = lyserg.moveset.base_abilities[0]
	if caster_kit == null or not caster_kit.has_method("apply_morphin_mark"):
		return
	caster_kit.apply_morphin_mark(context, lyserg, chosen)

func random_mark_tick(context):
	var lyserg = context['effect'].user
	_apply_random_mark(context, lyserg)

func retal_mark(context):
	var attacker = context['owner']
	var lyserg = context['target']
	if attacker == null or lyserg == null:
		return
	if attacker.dead or attacker.banished:
		return
	if not lyserg.is_hostile(attacker):
		return
	var caster_kit = lyserg.moveset.base_abilities[0]
	if caster_kit == null or not caster_kit.has_method("apply_morphin_mark"):
		return
	caster_kit.apply_morphin_mark(context, lyserg, attacker)

func extra_usable(user):
	return not user.has_effect("Mastema Dolkeen", EffectType.Type.MARK, user)

func custom_behavior(context):
	return behavior_self_panic_button(context, 30, 1.2)

func target(user, battle):
	default_self_target_function(user, battle)
