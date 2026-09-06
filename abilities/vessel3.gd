extends Ability

# Combat Direction — target enemy is Shattered for 2 turns and takes 5 more non-Affliction damage
# during that time (def_negate = Shattered; vulnerability excluding AFFLICTION = the +5 non-Affliction).
# Cost/cooldown/classes/target_type come from abilities_data.json via Ability.from_database.

func describe(user):
	return ""

func split_desc():
	return [
		["Target enemy is Shattered for 2 turns", Color.ORANGE_RED],
		"While Shattered, they take 5 more non-Affliction damage",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var shatter = Effect.def_negate(3)   # 3 == 2 turns
		shatter.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter)
		var vuln = Effect.vulnerability_effect(5, 3, [], [], [DamageType.Type.AFFLICTION])   # +5 non-Affliction, 2 turns
		vuln.set_source(self)
		Character.add_hostile_effect(context, user, target, vuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 5)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
