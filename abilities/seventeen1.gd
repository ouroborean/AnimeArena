extends Ability

var base_damage = 15
var stack_damage = 5

func describe(user):
	return "Deals 15 Affliction damage to target enemy and gives them 1 stack of 5 permanent Affliction damage. Gives 1 additional stack for each random energy this skill costs."

func split_desc():
	return [
		"Deals 15 Affliction damage to target enemy",
		"Applies a stack of 5 permanent Affliction damage",
		["+1 stack for each random energy this skill costs", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stacks_to_apply = 1 + cost()[Energy.Type.RANDOM]
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		var hellfire = Effect.damage_effect(stack_damage, DamageType.Type.AFFLICTION, -1)
		hellfire.set_source(self)
		hellfire.stackable = true
		hellfire.per_stack = true
		hellfire.display_stacks = true
		hellfire.stacks = stacks_to_apply
		Character.add_hostile_effect(context, user, target, hellfire)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 45)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
