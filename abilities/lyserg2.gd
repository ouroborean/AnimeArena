extends Ability

func describe(user):
	return "Each enemy with at least 1 Morphin Mark is stunned for 1 turn and has 1 mark removed. If there are 3 or more Morphin Marks active, this skill is replaced by Big Ben Wire Frame."

func split_desc():
	return [
		"Each enemy with at least 1 Morphin Mark is stunned for 1 turn and loses 1 Morphin Mark",
		["If 3 or more Morphin Marks are active, this skill is replaced by Big Ben Wire Frame", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target.dead or target.banished:
			continue
		if not user.is_hostile(target):
			continue
		var mark = target.effects.has_effect("Homing Pendulum", EffectType.Type.MARK, user)
		if mark == null:
			continue

		var stun = Effect.stun_effect(2)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

		mark.stacks -= 1
		if mark.stacks <= 0:
			target.effects.erase_effect(mark)
		else:
			mark.effect_updated.emit(mark)

func extra_usable(user):
	for e in user.battle.all_characters():
		if user.is_hostile(e) and not (e.dead or e.banished):
			if e.effects.has_effect("Homing Pendulum", EffectType.Type.MARK, user):
				return true
	return false

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 40, 1.1)

func target(user, battle):
	default_hostile_target_function(user, battle, false, "Homing Pendulum")
