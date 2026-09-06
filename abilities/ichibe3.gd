extends Ability

var stack_requirement = 4

func describe(user):
	return "For the rest of the game, target enemy is Silenced, their Strategic skills are Stunned, and their outgoing damage is capped at 10. Target must have at least 4 stacks of Ink Splatter. All effects are removed if Ichibe dies."

func split_desc():
	return [
		"For the rest of the game, target enemy is Silenced.",
		"Their Strategic skills are Stunned.",
		"Their outgoing damage is capped at 10.",
		["Target must have at least 4 stacks of Ink Splatter.", Color.CADET_BLUE],
		["All effects are removed if Ichibe dies.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var silence = Effect.silence_effect(-1)
		silence.set_source(self)
		Character.add_hostile_effect(context, user, target, silence)

		var strat_stun = Effect.stun_effect(-1, ["Strategic"])
		strat_stun.set_source(self)
		Character.add_hostile_effect(context, user, target, strat_stun)

		var cap = Effect.damage_cap(10, -1)
		cap.set_source(self)
		Character.add_hostile_effect(context, user, target, cap)

func _has_enough_ink(user):
	for c in user.battle.all_characters():
		if user.is_hostile(c) and not (c.dead or c.banished):
			var eff = c.has_effect("Ink Splatter", EffectType.Type.MARK, user)
			if eff and eff.stack_count() >= stack_requirement:
				return true
	return false

func extra_usable(user):
	return _has_enough_ink(user)

func custom_behavior(context):
	return behavior_hostile_single_require_mark(context, "Ink Splatter", EffectType.Type.MARK, 90)

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for c in battle.all_characters():
		if user.is_hostile(c):
			var eff = c.has_effect("Ink Splatter", EffectType.Type.MARK, user)
			if eff and eff.stack_count() >= stack_requirement:
				check_hostile_target(user, c, context)
