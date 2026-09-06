extends Ability

func describe(user):
	return "Marks target enemy for 1 turn. On the following turn, reduces the target's current HP by Yoh's current HP. This is not considered damage."

func split_desc():
	return [
		"Marks target enemy for 1 turn. On the following turn, reduces the target's current HP by Yoh's current HP",
		["This HP loss is not considered damage", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mark = Effect.mark(3, "Yoh will drain this target's HP next turn.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)

		var drain = Effect.trigger_effect(
			Trigger.always(apply_hp_drain),
			EffectType.Type.TICKING_TRIGGER,
			3,
			"On the following turn, " + target.character_name + "'s HP will be reduced by Yoh's current HP.")
		drain.set_source(self)
		drain.last_turn_only = true
		drain.character_target = target
		Character.add_allied_effect(context, user, user, drain)

func apply_hp_drain(context):
	if context.effect.duration != 1:
		return
	var yoh = context['owner']
	var target = context.effect.character_target
	if target == null or target.dead or target.banished:
		return
	var new_hp = max(0, target.health.hp - yoh.health.hp)
	target.health.set_health(new_hp)
	target.update.emit()
	if new_hp <= 0:
		target.instant_kill(yoh, self)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 55, 1.2)

func target(user, battle):
	default_hostile_target_function(user, battle)
