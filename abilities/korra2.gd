extends Ability

# Air Control. Counters the first Mental skill an enemy uses, and swaps ALL of Korra's slots to their
# elemental attacks for the follow-up turn. If the counter lands, Air Wave costs 1 Random less for 1 turn.

func describe(user):
	return "For 1 turn, counters the first Mental skill used by one enemy. Swaps all of Korra's skills to their elemental attacks. If the counter succeeds, Air Wave costs 1 Random less for 1 turn. Invisible."

func split_desc():
	return [
		"For 1 turn, counters the first Mental skill used by target enemy",
		["Swaps all of Korra's skills to their elemental attacks", Color.AQUAMARINE],
		["If the counter succeeds, Air Wave costs 1 Random less for 1 turn", Color.CADET_BLUE],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter = Effect.counter_effect(Trigger.always(air_control_countered), EffectType.Type.COUNTER_USE, 2, "The first Mental skill used by this character will be countered.", ["Mental"])
		counter.set_source(self)
		counter.wrapup_func = default_counter_timeout
		counter.invisible = true
		Character.add_hostile_effect(context, user, target, counter)
	for pair in [[4, 0], [5, 1], [6, 2], [7, 3]]:
		var abi_swap = Effect.ability_swap_effect(pair[0], pair[1], user, 3)
		abi_swap.set_source(self)
		abi_swap.invisible = true
		Character.add_allied_effect(context, user, user, abi_swap)

func air_control_countered(context):
	var korra = context['effect'].user
	if korra != null and not (korra.dead or korra.banished):
		var discount = Effect.cost_mod_effect(-1, 2, Energy.Type.RANDOM, ["Air Wave"])
		discount.set_source(self)
		Character.add_allied_effect(QueryContext.from_game_state(korra, korra.battle), korra, korra, discount)
	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			var count = 0
			for skill in character.moveset.base_abilities:
				if skill.classes["Mental"]:
					count += 1
			variations.append([count * 45, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
