extends Ability

func describe(user):
	return "Executes the enemy affected by Gibbet if their HP is 35 or less."

func split_desc():
	return [
		"Executes the enemy affected by Gibbet if their HP is 35 or less",
	]

func execute(user, battle):
	var gibbet_target = _find_gibbet_target(user)
	if gibbet_target == null:
		return
	if gibbet_target.health.hp > 35:
		return
	gibbet_target.instant_kill(user, self)

func _find_gibbet_target(user):
	for enemy in user.battle.all_characters():
		if user.is_hostile(enemy) and not (enemy.dead or enemy.banished):
			if enemy.has_effect("Gibbet", EffectType.Type.MARK, user):
				return enemy
	return null

func extra_usable(user):
	if user.has_effect("Iron Maiden", EffectType.Type.MARK, user):
		return false
	var target = _find_gibbet_target(user)
	if target == null:
		return false
	return target.health.hp <= 35

func custom_behavior(context):
	return behavior_single_target_damage(context, 90, 2.0)

func target(user, battle):
	var gibbet_target = _find_gibbet_target(user)
	if gibbet_target != null:
		gibbet_target.set_targeted()
