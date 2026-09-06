extends Ability

# Strike — 15 damage to one enemy.
# Cost/cooldown/classes/target_type come from abilities_data.json via Ability.from_database.

var base_damage = 15

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 15 damage to target enemy",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, base_damage)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
