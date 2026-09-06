extends Ability

var base_damage = 30
var damage_per_transformation = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 30 Piercing damage to target enemy. Deals +5 damage per time Cell has transformed."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy",
		["+5 damage per Genetic Perfection transformation (capped at +10)", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var transformations = 0
	var counter = user.has_effect("Genetic Perfection", EffectType.Type.MARK, user)
	if counter:
		transformations = counter.stack_count()
	var damage = base_damage + damage_per_transformation * transformations
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
