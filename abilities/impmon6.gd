extends Ability
var base_damage = 30

func describe(user):
	return "Deals 30 damage to target enemy. That enemy ignores all healing for 1 turn."

func split_desc():
	return [
		"Deals 30 damage to target enemy",
		["The target ignores all healing for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.ENERGY)
		var heal_ignore = Effect.ignore_healing(2)
		heal_ignore.set_source(self)
		Character.add_hostile_effect(context, user, target, heal_ignore)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
