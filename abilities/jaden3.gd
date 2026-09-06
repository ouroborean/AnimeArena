extends Ability

func describe(user):
	return "For 3 turns, Jaden's entire team gains 10 Shield that increases by 5 each turn. This skill is replaced by Elemental HERO Mudballman."

func split_desc():
	return [
		"For 3 turns, Jaden's entire team gains 10 Shield",
		"That Shield increases by 5 each turn",
		"This skill is replaced by Elemental HERO Mudballman"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Team-wide Clayman Shield: every living ally (Jaden included) gets 10 Shield now. Jaden must be
	# among the recipients so the Mudballman/Rampart fusions' SHIELD cleanup still finds his Shield.
	for ally in user.team.characters:
		if ally.dead or ally.banished:
			continue
		var shield = Effect.shield_effect(10, 6)
		shield.set_source(self)
		Character.add_allied_effect(context, user, ally, shield)

	var tick_desc = func(eff):
		return "Jaden's team's Elemental HERO Clayman Shield gains 5 each turn."
	var trigger = Effect.trigger_effect(
		Trigger.always(clayman_tick),
		EffectType.Type.TICKING_TRIGGER, 5, tick_desc
	)
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

	var swap = Effect.ability_swap_effect(6, 2, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func clayman_tick(context):
	var jaden = context['owner']
	# Bump every living ally's Clayman Shield by 5. Clayman is deliberately absent from
	# character_component.HERO_SHIELD_BOUND, so a broken Shield does not tear the form down; rebuild
	# it (inheriting the ticker's remaining duration) so the "+5 each turn" promise keeps holding for
	# the rest of the window instead of the ticker spinning uselessly after the first break.
	for ally in jaden.team.characters:
		if ally.dead or ally.banished:
			continue
		var bumped = false
		for shield in ally.get_shield_effects():
			if shield.source and shield.source.ability_name == "Elemental HERO Clayman":
				shield.change_mag(5)
				bumped = true
				break
		if not bumped:
			var regrown = Effect.shield_effect(5, context['effect'].duration)
			regrown.set_source(self)
			Character.add_allied_effect(QueryContext.from_game_state(jaden, jaden.battle), jaden, ally, regrown)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context)

func target(user, battle):
	default_self_target_function(user, battle)
