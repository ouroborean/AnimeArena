extends Ability

var base_damage = 35

func describe(user):
	return "Only usable if Jaden is currently under the effect of Elemental HERO Avian and Elemental HERO Burstinatrix. Jaden permanently gains 45 Shield. As long as this Shield persists, he deals 35 damage to a random enemy each turn."

func split_desc():
	return [
		"Permanently deals 35 damage to a random enemy each turn",
		["Only usable with Avian + Burstinatrix active", Color.DIM_GRAY],
		"Consumes Avian and Burstinatrix effects",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Consume component effects. Neither Avian nor Burstinatrix grants a Shield any more
	# (patch 2026-08-02), so their SHIELD removals are gone — Clayman is the only base HERO left
	# with one, and jaden6/jaden7 still strip it.
	user.effects.remove_effect("Elemental HERO Avian", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Avian", EffectType.Type.ABILITY_SWAP, user)
	user.effects.remove_effect("Elemental HERO Burstinatrix", EffectType.Type.TICKING_TRIGGER, user)
	user.effects.remove_effect("Elemental HERO Burstinatrix", EffectType.Type.ABILITY_SWAP, user)


	# First-turn random enemy damage
	var valid_targets = []
	for character in user.battle.all_characters():
		if user.is_hostile(character) and not character.is_invuln(self) \
				and not (character.dead or character.banished):
			valid_targets.append(character)
	if len(valid_targets) > 0:
		var target = valid_targets[user.battle.roll(0, len(valid_targets) - 1)]
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)

	var tick_desc = func(eff):
		return "Jaden will deal 35 damage to a random enemy each turn."
	var trigger = Effect.trigger_effect(
		Trigger.always(flame_wingman_tick),
		EffectType.Type.TICKING_TRIGGER, -1, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func flame_wingman_tick(context):
	var jaden = context['owner']
	var valid_targets = []
	for character in jaden.battle.all_characters():
		if jaden.is_hostile(character) and not character.is_invuln(self) \
				and not (character.dead or character.banished):
			valid_targets.append(character)
	if len(valid_targets) < 1:
		return
	var target = valid_targets[jaden.battle.roll(0, len(valid_targets) - 1)]
	Character.resolve_effect_damage(
		context, context['effect'], target, base_damage, DamageType.Type.NORMAL
	)

func extra_usable(user):
	# The ingredient handle is the base HERO's ABILITY_SWAP, not its TICKING_TRIGGER. The swap is
	# non-cleansable (form-change identity state), so a Helpful cleanse (e.g. Inuyasha's Iron Reaver)
	# no longer strips the ingredient token and grays the fusion out. The swap shares the trigger's
	# lifetime and is consumed alongside it when a fusion is cast, so this never allows a re-fuse.
	var has_avian = user.has_effect(
		"Elemental HERO Avian", EffectType.Type.ABILITY_SWAP, user
	)
	var has_burstinatrix = user.has_effect(
		"Elemental HERO Burstinatrix", EffectType.Type.ABILITY_SWAP, user
	)
	var has_self = user.has_effect(
		ability_name, EffectType.Type.TICKING_TRIGGER, user
	)
	return not has_self and has_avian and has_burstinatrix

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
