extends Ability

func describe(user):
	return "Heals Jesse 15 HP and gives him one stack of Crystal Beasts."

func split_desc():
	return [
		"Heals Jesse 15 HP and gives him one stack of Crystal Beasts.",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# Heal Jesse
	Character.resolve_healing(context, user, 15)

	# Add 1 stack of Crystal Beasts (source set to jesse1 so stacks share the same effect)
	var crystal_beasts_ability = user.moveset.base_abilities[0]
	var mark = Effect.mark(-1, "Crystal Beasts will deal 5 more damage per stack.")
	mark.set_source(crystal_beasts_ability)
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)
	var cb_eff = user.has_effect("Crystal Beasts", EffectType.Type.MARK, user)
	if cb_eff and cb_eff.stacks >= 7:
		var swap = Effect.ability_swap_effect(4, 0, user, -1)
		swap.set_source(crystal_beasts_ability)
		Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_heal(context, 25, 1.0)

func target(user, battle):
	default_self_target_function(user, battle)
