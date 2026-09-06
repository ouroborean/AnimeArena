extends Ability

var base_damage = 25

func describe(user):
	return "Deals 25 damage to the enemy affected by Gibbet and increases the cost of their skills by 1 Random energy for 1 turn. If the target has 35 or less HP, this skill is replaced by Guillotine."

func split_desc():
	return [
		"Deals 25 damage to the enemy affected by Gibbet",
		"Increases the cost of the target's skills by 1 Random energy for 1 turn",
		["If the target has 35 or less HP, this skill is replaced by Guillotine", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var gibbet_target = _find_gibbet_target(user)
	if gibbet_target == null:
		return
	Character.resolve_damage(context, gibbet_target, base_damage, DamageType.Type.NORMAL)

	var cost_up = Effect.cost_mod_effect(1, 2, Energy.Type.RANDOM, [])
	cost_up.set_source(self)
	Character.add_hostile_effect(context, user, gibbet_target, cost_up)

func _find_gibbet_target(user):
	for enemy in user.battle.all_characters():
		if user.is_hostile(enemy) and not (enemy.dead or enemy.banished):
			if enemy.has_effect("Gibbet", EffectType.Type.MARK, user):
				return enemy
	return null

func extra_usable(user):
	if user.has_effect("Iron Maiden", EffectType.Type.MARK, user):
		return false
	return _find_gibbet_target(user) != null

func custom_behavior(context):
	return behavior_single_target_damage(context, 45, 1.2)

func target(user, battle):
	var gibbet_target = _find_gibbet_target(user)
	if gibbet_target != null:
		gibbet_target.set_targeted()
