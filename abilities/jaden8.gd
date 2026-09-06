extends Ability

func describe(user):
	return "Only usable if Jaden is currently under the effect of Elemental HERO Avian and Elemental HERO Bubbleman. Jaden permanently gains 45 Shield. As long as this Shield persists, Jaden will cleanse all Harmful effects on his team and heal his team 5 HP each turn."

func split_desc():
	return [
		"Permanently cleanses all enemy effects on Jaden's team each turn",
		"Heals Jaden's team 5 HP each turn",
		["Only usable with Avian + Bubbleman active", Color.DIM_GRAY],
		"Consumes Avian and Bubbleman effects",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Consume component effects. Neither Avian nor Bubbleman grants a Shield any more
	# (patch 2026-08-02), so their SHIELD removals are gone.
	user.effects.remove_effect("Elemental HERO Avian", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Avian", EffectType.Type.ABILITY_SWAP, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.ABILITY_SWAP, user)


	# First-turn cleanse + team heal
	for ally in user.team.characters:
		if ally.dead or ally.banished:
			continue
		ally.effects.cleanse_all_enemy_effects(ally)
		if not ally.is_isolated():
			Character.resolve_healing(context, ally, 5)

	var tick_desc = func(eff):
		return "Jaden will cleanse all Harmful effects on his team and heal his team 5 HP each turn."
	var trigger = Effect.trigger_effect(
		Trigger.always(mariner_tick),
		EffectType.Type.TICKING_TRIGGER, -1, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func mariner_tick(context):
	var jaden = context['owner']
	for ally in jaden.team.characters:
		if ally.dead or ally.banished:
			continue
		ally.effects.cleanse_all_enemy_effects(ally)
		if not ally.is_isolated():
			Character.resolve_effect_healing(context, context['effect'], ally, 5)

func extra_usable(user):
	# Ingredients are proved by the base HERO's ABILITY_SWAP, not its TICKING_TRIGGER. The swap is
	# non-cleansable (form-change identity state), so a Helpful cleanse (e.g. Inuyasha's Iron Reaver)
	# no longer strips the ingredient token and grays the fusion out. The swap shares the trigger's
	# lifetime and is consumed alongside it when a fusion is cast, so this never allows a re-fuse.
	var has_avian = user.has_effect(
		"Elemental HERO Avian", EffectType.Type.ABILITY_SWAP, user
	)
	var has_bubbleman = user.has_effect(
		"Elemental HERO Bubbleman", EffectType.Type.ABILITY_SWAP, user
	)
	var has_self = user.has_effect(
		ability_name, EffectType.Type.TICKING_TRIGGER, user
	)
	return not has_self and has_avian and has_bubbleman

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
