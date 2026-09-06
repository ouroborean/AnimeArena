extends Ability

# Hymn of Fire (Blue form swap-in — hidden index 4, pulled into slot 2 by Summon - Tusk).
# 30 Affliction damage. If this skill is Countered, its original target is Stunned for 1 turn — wired
# in character/jinwoo.gd via counter_response_trigger (execute() does not run on a countered skill).

func describe(user):
	return "Deals 30 Affliction damage to target enemy. If this skill is Countered, its original target is Stunned for 1 turn."

func split_desc():
	return [
		"Deals 30 Affliction damage to target enemy",
		["If Countered, the original target is Stunned for 1 turn", Color.MEDIUM_PURPLE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.AFFLICTION)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
