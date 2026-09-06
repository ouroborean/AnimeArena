extends Ability

func describe(user):
	return "Jaden permanently gains 25 Shield. As long as this Shield persists, all enemies receive 10 Affliction damage each turn and this skill is replaced by Elemental HERO Rampart Blaster."

func split_desc():
	return [
		"For 3 turns, all enemies receive 5 Affliction damage each turn",
		"This skill is replaced by Elemental HERO Rampart Blaster"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Burstinatrix no longer grants Shield (patch 2026-08-02). The TICKING_TRIGGER below is now the
	# state token the Flame Wingman / Rampart Blaster fusion gates read.

	# First-turn damage
	for character in user.battle.all_characters():
		if user.is_hostile(character) and not character.dead and not character.banished:
			Character.resolve_damage(context, character, 5, DamageType.Type.AFFLICTION)

	var tick_desc = func(eff):
		return "All enemies receive 5 Affliction damage each turn."
	var trigger = Effect.trigger_effect(
		Trigger.always(burstinatrix_tick),
		EffectType.Type.TICKING_TRIGGER, 5, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

	var swap = Effect.ability_swap_effect(5, 1, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func burstinatrix_tick(context):
	var jaden = context['owner']
	for character in jaden.battle.all_characters():
		if jaden.is_hostile(character) and not character.dead and not character.banished:
			Character.resolve_effect_damage(
				context, context['effect'], character, 5,
				DamageType.Type.AFFLICTION
			)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
