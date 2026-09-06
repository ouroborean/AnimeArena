extends Ability


func describe(user):
	return "At the start of each turn, a random ally is marked with Fairy Star Strategy. If they use a new skill while marked, Mavis gains 1 Fairy Star Strategy and they gain a benefit based on Mavis's stack count. 1: 10 Shield. 2: heal 20 HP. 3: permanently +10 non-Affliction damage. 4+: their skills cost nothing next turn."


func split_desc():
	return [
		"Each turn, a random ally is marked with Fairy Star Strategy (Invisible)",
		"If they use a new skill, Mavis gains 1 stack and they gain a stack-based reward",
		["1: 10 Shield · 2: 20 heal · 3: permanent +10 non-Affliction damage · 4+: free skills next turn", Color.CADET_BLUE],
	]


func execute(user, battle):
	var context = make_context(battle)
	var ticker = Effect.trigger_effect(
		Trigger.always(tag_random_ally),
		EffectType.Type.START_OF_TURN_TRIGGER,
		-1,
		"At the start of each turn, Mavis marks a random ally with Fairy Star Strategy.")
	ticker.system = true
	apply_allied(context, user, ticker)


func tag_random_ally(context):
	var mavis = context['effect'].user
	if mavis.dead or mavis.banished:
		return
	# Only mark on MAVIS'S team's turn, so a marked ally can actually act to trigger it.
	# `waiting_for_turn` tracks the side-1 (player) / side-2 (enemy) split, NOT Mavis's team:
	# when Mavis is the SECOND player her team is the `enemy` side, so the old
	# `if user.battle.waiting_for_turn: return` was inverted (in PvP it marked on the opponent's
	# turn and never on hers, then stuck to that tempo). Derive the acting team from the same
	# split and require Mavis to be on it — correct whether she is player 1 or player 2.
	var mbattle = mavis.battle
	var acting_team = mbattle.enemy.team if mbattle.waiting_for_turn else mbattle.player.team
	if not mavis in acting_team.characters:
		return
	var candidates = []
	for ally in mavis.team.characters:
		if ally.dead or ally.banished:
			continue
		if ally.has_effect("Fairy Heart", EffectType.Type.MARK, mavis):
			continue
		candidates.append(ally)
	if candidates.is_empty():
		return

	var pick = candidates[mavis.battle.roll(0, candidates.size() - 1)]
	var qc = QueryContext.from_game_state(mavis, mavis.battle)

	var mark = Effect.empty(1, "If this character uses a new skill, Mavis gains a Fairy Star and they gain a reward based on her stacks.")
	mark.invisible = true
	mark.refresh = true
	mark.set_source(self)
	Character.add_allied_effect(qc, mavis, pick, mark)

	var trig = Effect.trigger_effect(
		Trigger.always(fairy_star_used),
		EffectType.Type.ACTION_USE_TRIGGER,
		1,
		"")
	trig.system = true
	trig.refresh = true
	trig.set_source(self)
	Character.add_allied_effect(qc, mavis, pick, trig)


func fairy_star_used(context):
	var ally = context['owner']
	var mavis = context['effect'].user
	if mavis.dead or mavis.banished:
		ally.effects.remove_effect("Fairy Star Strategy", EffectType.Type.ACTION_USE_TRIGGER, mavis)
		ally.effects.remove_effect("Fairy Star Strategy", EffectType.Type.MARK, mavis)
		return

	var qc = QueryContext.from_game_state(mavis, mavis.battle)

	# Stack increment: re-applying a stackable mark adds 1 stack.
	var stacks_mark = Effect.mark(-1, "Mavis's strategy is advancing.")
	stacks_mark.stackable = true
	stacks_mark.display_stacks = true
	stacks_mark.set_source(self)
	Character.add_allied_effect(qc, mavis, mavis, stacks_mark)

	var n = mavis.has_effect("Fairy Star Strategy", EffectType.Type.MARK, mavis).stack_count()

	if n == 1:
		var shield = Effect.shield_effect(10, 2)
		shield.set_source(self)
		shield.unique_render_id = 5
		Character.add_allied_effect(qc, mavis, ally, shield)
	elif n == 2:
		Character.resolve_effect_healing(qc, context['effect'], ally, 20)
	elif n == 3:
		var dmod = Effect.damage_mod_effect(10, -1, [], [], [DamageType.Type.AFFLICTION])
		dmod.remove_on_death = false
		dmod.set_source(self)
		dmod.unique_render_id = 10
		dmod.cleansable = false
		Character.add_allied_effect(qc, mavis, ally, dmod)
	else:
		# ONE mark, not a COST_CHANGE per active skill. The old loop applied four separate effects
		# (so the holder showed four identical 1-turn tooltips), and because each was keyed to an
		# ability_name it missed any skill swapped or copied in afterwards - that new skill still
		# cost energy. Ability.cost() reads this mark last and returns a zero cost outright.
		# refresh so a re-trigger next turn replaces it instead of appending a second copy.
		var free = Effect.mark(4, "This character's skills have no cost.")
		free.set_source(self)
		free.name_override = FREE_SKILLS_MARK
		free.refresh = true
		Character.add_allied_effect(qc, mavis, ally, free)

	ally.effects.remove_effect("Fairy Star Strategy", EffectType.Type.ACTION_USE_TRIGGER, mavis)
	ally.effects.remove_effect("Fairy Star Strategy", EffectType.Type.EMPTY, mavis)


func extra_usable(user):
	return true


func custom_behavior(context):
	return [[0, [user, "PASS", []]]]


func target(user, battle):
	default_self_target_function(user, battle)
