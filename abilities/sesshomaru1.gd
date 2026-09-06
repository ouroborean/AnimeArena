extends Ability

# Bakusaiga. 20 Piercing damage + applies Destructive Corrosion (the sesshomaru6 effect source) to the
# target for 3 turns, refreshing. Bakusaiga is the ONLY way Destructive Corrosion reaches the field.

func describe(user):
	return "Deals 20 Piercing damage to target enemy and applies Destructive Corrosion to them for 3 turns."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy",
		["Applies Destructive Corrosion to them for 3 turns", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dc = user.moveset.base_abilities[5]   # Destructive Corrosion effect source
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.PIERCING)
		if not target.dead:
			dc.apply_corrosion(context, user, target)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
