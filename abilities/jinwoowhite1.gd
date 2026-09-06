extends Ability

# Vital Strike (White form). 25 damage to target enemy and heals Jin-woo 15 HP.

func describe(user):
	return "Deals 25 damage to target enemy and heals Jin-woo 15 HP."

func split_desc():
	return [
		"Deals 25 damage to target enemy",
		["Heals Jin-woo 15 HP", Color.LIME_GREEN],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 25, DamageType.Type.NORMAL)
	Character.resolve_healing(context, user, 15)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 25)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
