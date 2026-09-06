extends Ability

func describe(user):
	return "Jaden permanently gains 25 Shield. As long as this Shield persists, all enemies deal 5 less non-Affliction damage and this skill is replaced by Elemental HERO Flame Wingman."

func split_desc():
	return [
		"For 3 turns, all enemies deal 5 less non-Affliction damage",
		"This skill is replaced by Elemental HERO Flame Wingman"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Avian no longer grants Shield (patch 2026-08-02). The TICKING_TRIGGER below is now the
	# state token the Flame Wingman / Mariner fusion gates read.

	# First-turn debuff application
	for character in user.battle.all_characters():
		if user.is_hostile(character) and not character.dead and not character.banished:
			var debuff = Effect.damage_mod_effect(
				-5, 2, [], [], [DamageType.Type.AFFLICTION]
			)
			debuff.set_source(self)
			Character.add_hostile_effect(context, user, character, debuff)
	
	var tick_desc = func(eff):
		return "All enemies deal 5 less non-Affliction damage."
	var trigger = Effect.trigger_effect(
		Trigger.always(avian_tick),
		EffectType.Type.TICKING_TRIGGER, 5, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)
	
	var swap = Effect.ability_swap_effect(4, 0, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func avian_tick(context):
	var jaden = context['owner']
	for character in jaden.battle.all_characters():
		if jaden.is_hostile(character) and not character.dead and not character.banished:
			character.effects.remove_effect(
				"Elemental HERO Avian", EffectType.Type.DAMAGE_MOD, jaden
			)
			var debuff = Effect.damage_mod_effect(
				-5, 2, [], [], [DamageType.Type.AFFLICTION]
			)
			debuff.set_source(self)
			Character.add_hostile_effect(context, jaden, character, debuff)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
