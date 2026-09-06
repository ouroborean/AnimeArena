extends Ability

func describe(user):
	return "Applies 1 stack of Ink Splatter to all enemies, and applies 1 stack of Ink Splatter to Ichibe for each enemy inked. Ichibe also gains 5 permanent Damage Reduction per stack applied to him. If Ichibe has at least 10 stacks of Ink Splatter, this skill is permanently replaced with Futen Taisatsuryo."

func split_desc():
	return [
		"Applies 1 stack of Ink Splatter to all enemies.",
		"Ichibe gains 1 stack of Ink Splatter for each enemy inked.",
		["Ichibe gains 5 permanent Shield per stack applied to him.", Color.DIM_GRAY],
		["If Ichibe has 10 stacks of Ink Splatter, this skill is permanently replaced by Futen Taisatsuryo.", Color.AQUA],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var applied = 0
	for enemy in context.enemy_team.characters:
		if enemy.dead or enemy.banished:
			continue
		apply_ink_stack(context, user, enemy, true)
		applied += 1

	for i in range(applied):
		apply_self_ink_with_dr(context, user)

	check_futen_unlock(context, user)

func apply_ink_stack(context, user, target, hostile):
	var mark_desc = func (eff):
		return "This character has " + str(eff.stack_count()) + " stacks of Ink Splatter."
	var mark = Effect.mark(-1, mark_desc)
	mark.stackable = true
	mark.display_stacks = true
	mark.set_source(self)
	if hostile:
		Character.add_hostile_effect(context, user, target, mark)
	else:
		Character.add_allied_effect(context, user, target, mark)

func apply_self_ink_with_dr(context, user):
	apply_ink_stack(context, user, user, false)
	var dr = Effect.shield_effect(5, -1)
	dr.set_source(self)
	dr.stackable = true
	dr.display_mag = true
	dr.unique_render_id = 5
	dr.stack_mag = true
	Character.add_allied_effect(context, user, user, dr)

func check_futen_unlock(context, user):
	var self_ink = user.has_effect("Ink Splatter", EffectType.Type.MARK, user)
	var stacks = self_ink.stack_count() if self_ink else 0
	if stacks < 10:
		return
	for eff in user.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		if eff.mag is Vector2 and eff.mag.x == 4 and eff.mag.y == 1:
			return
	var swap = Effect.ability_swap_effect(4, 1, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 30, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
