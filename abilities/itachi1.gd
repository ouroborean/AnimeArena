extends Ability


func describe(user):
	return "Itachi targets one enemy for 1 turn (Invisible). During this time, if that enemy uses a new skill, Itachi's skills cost 1 less Random energy for 1 turn. If they target Itachi with that skill, his skills also cost 1 less White energy for 1 turn. If either effect is triggered, the enemy takes 10 Piercing damage."


func split_desc():
	return [
		"For 1 turn, marks target enemy (Invisible)",
		["Itachi gains 10 invisible Shield", Color.CADET_BLUE],
		["If they use a new skill, Itachi's skills cost 1 less Random energy next turn", Color.CADET_BLUE],
		["If that skill targeted Itachi, also costs 1 less White energy next turn", Color.CADET_BLUE],
		["On trigger, the marked enemy takes 10 Piercing damage (twice if the skill targeted Itachi)", Color.CADET_BLUE],
	]


func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(
			Trigger.always(crow_trigger),
			EffectType.Type.ACTION_USE_TRIGGER,
			2,
			"If this character uses a new skill, Itachi gains a cost discount and they take 10 Piercing damage. If that skill targets Itachi, they take the damage twice.")
		trigger.invisible = true
		apply_hostile(context, target, trigger)
	var shield = Effect.shield_effect(10, -1)
	shield.invisible = true
	apply_allied(context, user, shield)


func crow_trigger(context):
	var enemy = context['owner']
	var itachi = context['effect'].user
	if enemy.dead or enemy.banished:
		return
	if itachi.dead or itachi.banished:
		enemy.effects.remove_effect("Crow Clone", EffectType.Type.ACTION_USE_TRIGGER, itachi)
		return

	var qc = QueryContext.from_game_state(itachi, itachi.battle)
	var random_mod = Effect.cost_mod_effect(-1, 2, Energy.Type.RANDOM)
	random_mod.unique_render_id = 5
	apply_allied(qc, itachi, random_mod)
	if itachi in enemy.targeter.targets:
		apply_allied(qc, itachi, Effect.cost_mod_effect(-1, 2, Energy.Type.WHITE))

	var stored = itachi.used_ability
	itachi.used_ability = self
	Character.resolve_damage(qc, enemy, 10, DamageType.Type.PIERCING)
	if itachi in enemy.targeter.targets:
		Character.resolve_damage(qc, enemy, 10, DamageType.Type.PIERCING)
	itachi.used_ability = stored

	# Breadcrumb so Tsukuyomi can read "damaged by Crow Clone last turn".
	var memo = Effect.mark(2, "Crow Clone damaged this character last turn.")
	memo.invisible = true
	memo.system = true
	apply_hostile(qc, enemy, memo, true)

	enemy.effects.remove_effect("Crow Clone", EffectType.Type.ACTION_USE_TRIGGER, itachi)


func extra_usable(user):
	return true


func custom_behavior(context):
	return behavior_single_target_hostile(context, 25)


func target(user, battle):
	default_hostile_target_function(user, battle)
