extends Ability

# Burning Wrath Blade (HIDDEN, base_abilities index 5). Swapped into slot 2 for 1 turn by the
# third stage of Burning Wrath Whirl (tsubasa3). Big Affliction hit + a permanent Taunt.
# Modeled on machinedramon1 / hinata4 (permanent taunt via add_hostile_effect bypassing).

func describe(user):
	return "Deals 40 Affliction damage to target enemy and permanently Taunts them."

func split_desc():
	return [
		"Deals 40 Affliction damage to target enemy",
		["Permanently Taunts them", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 40, DamageType.Type.AFFLICTION)
		var taunt = Effect.taunt_effect(-1, user)
		taunt.set_source(self)
		Character.add_hostile_effect(context, user, target, taunt, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
