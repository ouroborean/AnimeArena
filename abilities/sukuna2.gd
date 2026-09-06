extends Ability

# Fire Arrow. A flat 35 True damage strike — no HP thresholds, no set-HP, no execute, no riders.
# Still gated behind Malevolent Shrine (granted by sukuna1 / sukuna4), same as Cleave and Dismantle.

func describe(user):
	return "Deals 35 True damage to target enemy."

func split_desc():
	return [
		"Deals 35 True damage to target enemy",
		["Requires Malevolent Shrine", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 35, DamageType.Type.TRUE)

func extra_usable(user):
	return user.marked_by("Malevolent Shrine")

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
