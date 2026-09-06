extends Ability
var base_damage = 30

# Axe Smash. Stark's baseline swing, and the slot Cleaving Light and Lightning Strike take over when
# the board gives him a better option (see character/stark.gd, which owns that evaluation).

func describe(user):
	return "Deals 30 Piercing damage to target enemy."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	deal_damage_to_targets(context, base_damage, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, base_damage)

func target(user, battle):
	default_hostile_target_function(user, battle)
