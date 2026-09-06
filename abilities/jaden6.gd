extends Ability

func describe(user):
	return "Only usable if Jaden is currently under the effect of Elemental HERO Clayman and Elemental HERO Burstinatrix. Jaden permanently gains 45 Shield. As long as this Shield persists, all enemies are Shattered and cannot gain Shield."

func split_desc():
	return [
		"Permanently, all enemies are Shattered and cannot gain Shield",
		["Only usable with Clayman + Burstinatrix active", Color.DIM_GRAY],
		"Consumes Clayman and Burstinatrix effects",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Consume component effects. Clayman is the only base HERO that still grants a Shield
	# (patch 2026-08-02), so Burstinatrix's SHIELD removal is gone.
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.SHIELD, user)
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.ABILITY_SWAP, user)
	user.effects.remove_effect("Elemental HERO Burstinatrix", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Burstinatrix", EffectType.Type.ABILITY_SWAP, user)

	# First-turn shatter application
	for character in user.battle.all_characters():
		if user.is_hostile(character) and not character.dead and not character.banished:
			var shatter = Effect.def_negate(2)
			shatter.set_source(self)
			Character.add_hostile_effect(context, user, character, shatter)
			var no_shield = Effect.ignore_effect_effect(2, EffectType.Type.SHIELD)
			no_shield.set_source(self)
			Character.add_hostile_effect(context, user, character, no_shield)

	var tick_desc = func(eff):
		return "All enemies are Shattered and cannot gain Shield."
	var trigger = Effect.trigger_effect(
		Trigger.always(rampart_tick),
		EffectType.Type.TICKING_TRIGGER, -1, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func rampart_tick(context):
	var jaden = context['owner']
	for character in jaden.battle.all_characters():
		if jaden.is_hostile(character) and not character.dead and not character.banished:
			character.effects.remove_effect(
				"Elemental HERO Rampart Blaster", EffectType.Type.DEF_NEGATE, jaden
			)
			character.effects.remove_effect(
				"Elemental HERO Rampart Blaster", EffectType.Type.IGNORE_EFFECT, jaden
			)
			var shatter = Effect.def_negate(2)
			shatter.set_source(self)
			Character.add_hostile_effect(context, jaden, character, shatter)

			var no_shield = Effect.ignore_effect_effect(2, EffectType.Type.SHIELD)
			no_shield.set_source(self)
			Character.add_hostile_effect(context, jaden, character, no_shield)

func extra_usable(user):
	# Both ingredients are proved by the base HERO's ABILITY_SWAP, not its TICKING_TRIGGER. The swap
	# is non-cleansable (form-change identity state), so a Helpful cleanse (e.g. Inuyasha's Iron
	# Reaver) no longer strips the ingredient token and grays the fusion out. The swap shares the
	# trigger's lifetime and is consumed alongside it when a fusion is cast, so this never re-fuses.
	var has_clayman = user.has_effect(
		"Elemental HERO Clayman", EffectType.Type.ABILITY_SWAP, user
	)
	var has_burstinatrix = user.has_effect(
		"Elemental HERO Burstinatrix", EffectType.Type.ABILITY_SWAP, user
	)
	var has_self = user.has_effect(
		ability_name, EffectType.Type.TICKING_TRIGGER, user
	)
	return not has_self and has_clayman and has_burstinatrix

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
