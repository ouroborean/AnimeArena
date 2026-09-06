extends Ability

func describe(user):
	return "Only usable if Jaden is currently under the effect of Elemental HERO Clayman and Elemental HERO Bubbleman. Jaden permanently gains 100 Shield."

func split_desc():
	return [
		"Jaden permanently gains 80 Shield",
		["Only usable with Clayman + Bubbleman active", Color.DIM_GRAY],
		"Consumes Clayman and Bubbleman effects",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Consume component effects. Clayman is the only base HERO that still grants a Shield
	# (patch 2026-08-02), so Bubbleman's SHIELD removal is gone.
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.SHIELD, user)
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Clayman", EffectType.Type.ABILITY_SWAP, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Bubbleman", EffectType.Type.ABILITY_SWAP, user)

	var shield = Effect.shield_effect(80, -1)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)

func extra_usable(user):
	# Ingredients are proved by the base HERO's ABILITY_SWAP, not its TICKING_TRIGGER. The swap is
	# non-cleansable (form-change identity state), so a Helpful cleanse (e.g. Inuyasha's Iron Reaver)
	# no longer strips the ingredient token and grays the fusion out; it is consumed alongside the
	# trigger when a fusion is cast. `has_self` below still reads SHIELD — Mudballman's own permanent
	# 80 Shield IS this fusion's state.
	var has_clayman = user.has_effect(
		"Elemental HERO Clayman", EffectType.Type.ABILITY_SWAP, user
	)
	var has_bubbleman = user.has_effect(
		"Elemental HERO Bubbleman", EffectType.Type.ABILITY_SWAP, user
	)
	var has_self = user.has_effect(
		ability_name, EffectType.Type.SHIELD, user
	)
	return not has_self and has_clayman and has_bubbleman

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
