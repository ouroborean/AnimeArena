extends Ability

func describe(user):
	return "Marks target enemy for 1 turn. During this time, any non-Bleed damage they would take is prevented, then dealt to them as Bleed damage on the following turn."

func split_desc():
	return [
		"Marks target enemy for 1 turn",
		["Non-Bleed damage they would take is prevented and dealt as Bleed next turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# The MARK is the interception window — the deal_ability_damage / deal_effect_damage engine hook
		# funnels the raw non-Bleed damage of a "Blood Spear"-marked target into the payload below.
		var mark = Effect.mark(2, "Non-Bleed damage this character takes is prevented and re-dealt as Bleed next turn.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
		# The accumulator: a BLEED DAMAGE effect starting at 0 that the hook grows, then ticks next turn
		# as a single Bleed lump. Named "Blood Spear" so the hook's has_effect(...DAMAGE) finds it.
		var payload = Effect.damage_effect(0, DamageType.Type.BLEED, 3)
		payload.set_source(self)
		payload.last_turn_only = true
		Character.add_hostile_effect(context, user, target, payload)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
