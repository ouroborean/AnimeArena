extends Ability

func describe(user):
	return "Another ally permanently gains One For All, and All Might permanently receives 10 more Affliction damage from his own skills. This skill can only be used once."

func split_desc():
	return [
		"Another ally permanently gains One For All.",
		["All Might permanently takes 10 more Affliction damage from his own skills.", Color.DIM_GRAY],
		["When All Might dies, the affected ally's colored costs become Random costs.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = make_context(battle)
	var one_for_all = user.moveset.base_abilities[4]

	for ally in user.targeter.targets:
		one_for_all.apply_one_for_all(context, user, ally)

	var declared = Effect.mark(-1, "All Might has named a successor.")
	declared.set_source(self)
	declared.invisible = true
	declared.stackable = true
	declared.remove_on_death = false
	declared.cleansable = false
	Character.add_allied_effect(context, user, user, declared)

	var on_death = Effect.trigger_effect(
		Trigger.always(on_allmight_death),
		EffectType.Type.ON_DEATH_TRIGGER,
		-1,
		"When All Might dies, allies with One For All have their colored costs changed to Random costs.")
	on_death.set_source(self)
	on_death.invisible = true
	on_death.remove_on_death = false
	Character.add_allied_effect(context, user, user, on_death)

func on_allmight_death(context):
	var allmight = context['effect'].user
	var one_for_all = allmight.moveset.base_abilities[4]
	for character in context.battle.all_characters():
		if not character in allmight.team.characters:
			continue
		if character == allmight:
			continue
		if character.has_effect("One For All", EffectType.Type.ACTION_USE_TRIGGER, allmight) == null:
			continue
		one_for_all.apply_post_death_color_changes(context, allmight, character)

func extra_usable(user):
	return user.has_effect("Declare Successor", EffectType.Type.MARK, user) == null

func custom_behavior(context):
	return behavior_single_target_selfless_helpful(context, 80)

func target(user, battle):
	default_allied_target_function(user, battle)
