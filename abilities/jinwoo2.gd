extends Ability

# Hand of the Monarch (default form). Stuns the target's non-Strategic skills for 1 turn. While Shadow
# Summon is active, it also marks the target so Shadow Summon's per-turn damage strikes that enemy
# exclusively (a fresh cast re-points the mark). The MARK is named "Hand of the Monarch" (its source),
# which jinwoo3's shadow_tick reads.

func describe(user):
	return "Stuns target enemy's non-Strategic skills for 1 turn. If Shadow Summon is active, it will damage that enemy exclusively until Hand of the Monarch is used again."

func split_desc():
	return [
		"Stuns target enemy's non-Strategic skills for 1 turn",
		["While Shadow Summon is active, its damage strikes this enemy exclusively until Hand of the Monarch is used again", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shadow_active = user.has_effect("Shadow Summon", EffectType.Type.MARK, user) != null
	if shadow_active:
		# One exclusive target at a time — clear any previous mark first.
		for enemy in context['enemy_team'].characters:
			enemy.effects.remove_effect("Hand of the Monarch", EffectType.Type.MARK, user)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(2, [], ["Strategic"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		if shadow_active:
			var mark = Effect.mark(-1, "Shadow Summon strikes this enemy exclusively.")
			mark.set_source(self)
			Character.add_hostile_effect(context, user, target, mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
