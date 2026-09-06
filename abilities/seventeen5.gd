extends Ability

func describe(user):
	return "Each time Android 17 uses a skill, he gains 1 Random energy and his skills permanently cost 1 more Random energy. If he uses a skill that costs 3 energy, all stacks of this effect are removed."

func split_desc():
	return [
		"When Android 17 uses a skill costing 3 or more energy, he gains 1 Random energy",
		["That also removes every stack of this effect", Color.CADET_BLUE],
		"Any cheaper skill instead makes his skills permanently cost 1 more Random energy (stacks)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var watcher = Effect.trigger_effect(
		Trigger.always(cycling_trigger),
		EffectType.Type.ACTION_USE_TRIGGER,
		-1,
		""
	)
	watcher.set_source(self)
	watcher.system = true
	Character.add_allied_effect(context, user, user, watcher)

func cycling_trigger(context):
	var seventeen = context['effect'].user
	if seventeen == null or seventeen.dead or seventeen.banished:
		return
	var used_skill = context['source']
	if not (used_skill is Ability):
		return

	var cost_paid = used_skill.cost()
	var total_cost = 0
	for element in cost_paid:
		total_cost += cost_paid[element]

	# The bonus energy is now the reward for a 3+ energy skill specifically, not
	# for using any skill at all. `cost()` is the RESOLVED cost, so it already
	# counts this passive's own +1 Random per stack (and any enemy cost increase)
	# — the threshold is partly self-fulfilling by design.
	if total_cost >= 3:
		seventeen.gain_random_energy()
		var stacks = seventeen.effects.has_effect("Infinite Energy Cycling", EffectType.Type.COST_MOD, seventeen)
		if stacks:
			seventeen.effects.erase_effect(stacks)
		return

	var qc = QueryContext.from_game_state(seventeen, seventeen.battle)
	var surge = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM)
	surge.set_source(self)
	surge.stackable = true
	surge.per_stack = true
	surge.display_stacks = true
	Character.add_allied_effect(qc, seventeen, seventeen, surge)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
