extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 Piercing damage to target enemy and permanently lowers the damage they deal by 5."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy",
		"Permanently lowers the damage that enemy deals by 5"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		user.manually_advance_mission(9, 1)
		var weakness = Effect.damage_mod_effect(-5, -1)
		weakness.stackable = true
		weakness.per_stack = true
		weakness.display_stacks = true
		weakness.set_source(self)
		Character.add_hostile_effect(context, user, target, weakness)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
