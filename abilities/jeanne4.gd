extends Ability

func describe(user):
	return "Jeanne or target ally becomes Invulnerable for 1 turn. If that ally is dead, they are instead resurrected with 35 HP."

func split_desc():
	return [
		"Jeanne or target ally becomes Invulnerable for 1 turn",
		"If the target ally is dead, they are instead resurrected with 35 HP",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target.dead:
			target.dead = false
			target.health.set_health(35)
			target.update.emit()
		else:
			var invuln = Effect.invuln_effect(2)
			invuln.set_source(self)
			Character.add_allied_effect(context, user, target, invuln)

func extra_usable(user):
	if user.has_effect("Iron Maiden", EffectType.Type.MARK, user):
		return false
	return true

func custom_behavior(context):
	var has_dead_ally = false
	for ally in user.team.characters:
		if ally != user and ally.dead and not ally.banished:
			has_dead_ally = true
			break
	if has_dead_ally:
		return behavior_single_target_helpful(context, 70)
	return behavior_single_target_helpful(context, 35)

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in user.team.characters:
		if character.banished:
			continue
		if character.dead:
			character.set_targeted()
		else:
			check_allied_target(user, character, context, false)
