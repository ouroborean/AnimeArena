extends Ability

func describe(user):
	return "Lyserg targets 1 enemy. After 2 turns, that enemy takes 20 damage, increased by 20 for each Morphin Mark on them. While this skill is active, the affected enemy will be executed if their HP falls below 10, increased by 10 for each Morphin Mark on them."

func split_desc():
	return [
		"Lyserg targets 1 enemy",
		"After 2 turns, that enemy takes 15 damage, +15 per Morphin Mark on them",
		"While active, the target is executed if their HP falls below 15, +15 per Morphin Mark on them",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mark = Effect.mark(5, "This character will take 15 damage, increased by 15 for each Morphin Mark on them.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)

		var det = Effect.trigger_effect(
			Trigger.always(detonate),
			EffectType.Type.TICKING_TRIGGER,
			5,
			"Big Ben Wire Frame detonates on " + target.character_name + " in 2 turns.")
		det.set_source(self)
		det.last_turn_only = true
		det.character_target = target
		Character.add_allied_effect(context, user, user, det)

		var exec = Effect.trigger_effect(
			Trigger.always(execute_check),
			EffectType.Type.DAMAGE_RECEIVE_TRIGGER,
			4,
			"")
		exec.set_source(self)
		exec.system = true
		Character.add_hostile_effect(context, user, target, exec)

func detonate(context):
	if context['effect'].duration != 1:
		return
	var lyserg = context['effect'].user
	var target = context['effect'].character_target
	if target == null or target.dead or target.banished:
		return

	var marks = target.effects.has_effect("Homing Pendulum", EffectType.Type.MARK, lyserg)
	var stacks = marks.stacks if marks else 0
	var damage = 15 + 15 * stacks

	var stored = lyserg.used_ability
	lyserg.used_ability = self
	Character.resolve_damage(QueryContext.from_game_state(lyserg, lyserg.battle), target, damage, DamageType.Type.NORMAL)
	lyserg.used_ability = stored

	target.effects.full_remove_effect_by_name("Big Ben Wire Frame", lyserg)

func execute_check(context):
	var target = context['target']
	var lyserg = context['effect'].user
	if target.dead or target.banished:
		return
	if target.health.hp <= 0:
		return
	var marks = target.effects.has_effect("Homing Pendulum", EffectType.Type.MARK, lyserg)
	var stacks = marks.stacks if marks else 0
	var threshold = 15 + 15 * stacks
	if target.health.hp < threshold:
		target.instant_kill(lyserg, self)

func extra_usable(user):
	return not user.has_effect("Mastema Dolkeen", EffectType.Type.MARK, user)

func custom_behavior(context):
	return behavior_single_target_damage(context, 45, 1.3)

func target(user, battle):
	default_hostile_target_function(user, battle)
