extends Ability

const DIARY = "Yukiteru Diary"

func describe(user):
	return "For 1 turn, counters the first Harmful skill used on one of Yuno's allies marked by Yukiteru Diary (cannot target Yuno herself). If they have 2 or more stacks, it counters all skills used on them during that time. If a countered enemy is marked by Yukiteru Diary, Axe Crazy will be used on them."

func split_desc():
	return [
		"For 1 turn, counters the first Harmful skill used on one of Yuno's Diary-marked allies (not Yuno)",
		["If they have 2+ stacks, counters every skill used on them for that turn", Color.CADET_BLUE],
		["When a countered enemy is marked by Yukiteru Diary, Axe Crazy is used on them", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var m = target.marked_by(DIARY)
		var counter_all = m != null and m.stack_count() >= 2
		var types = [] if counter_all else ["Harmful"]
		var desc = "Knife Deflection: every skill used on this character is countered." if counter_all else "Knife Deflection: the next Harmful skill used on this character is countered."
		var counter = Effect.counter_effect(Trigger.always(knife_counter_fired), EffectType.Type.COUNTER_RECEIVE, 2, desc, types)
		counter.wrapup_func = default_counter_timeout
		# Invisible so the enemy can't see the counter waiting on the ally (matches adam2 Divine Counter
		# / uranus2 Intercepting Strike). Paired with the "Invisible" ability class in the data files.
		counter.invisible = true
		counter.set_source(self)
		Character.add_allied_effect(context, user, target, counter)

# Fired from Character.countered(): context['owner'] is the attacker, context['effect'].user is Yuno.
func knife_counter_fired(context):
	var yuno = context['effect'].user
	var attacker = context['owner']
	if attacker != null and not (attacker.dead or attacker.banished) and not (yuno.dead or yuno.banished) and attacker.marked_by(DIARY):
		# Yuno swings Axe Crazy at the countered enemy. Save/set/restore mirrors adam2.gd's stolen-skill idiom.
		var axe = yuno.moveset.base_abilities[0]
		var tgt_storage = yuno.targeter.targets
		var main_storage = yuno.targeter.main_target
		var used_storage = yuno.used_ability
		var axe_user_save = axe.user
		axe.user = yuno
		yuno.used_ability = axe
		yuno.targeter.targets = [attacker]
		yuno.targeter.main_target = attacker
		axe.execute(yuno, yuno.battle)
		yuno.targeter.targets = tgt_storage
		yuno.targeter.main_target = main_storage
		yuno.used_ability = used_storage
		axe.user = axe_user_save
	# Harmful-only counter (1 stack) is consumed after firing; the all-skill counter (2+ stacks) persists.
	# Either way, announce the counter (default_counter_trigger consumes + notifies; the persistent variant
	# only notifies, leaving the counter active for the rest of the turn).
	if context['effect'].class_targets != []:
		default_counter_trigger(context)
	else:
		default_persistent_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_selfless_helpful(context, 40)   # protects an ally, not Yuno
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for ally in user.team.characters:
		if ally == user:   # protects an ally, never Yuno herself
			continue
		if ally.marked_by(DIARY):
			check_allied_target(user, ally, context)
