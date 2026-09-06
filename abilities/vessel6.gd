extends Ability

# Disarm — target enemy is stunned for 1 turn. An ALTERNATE Vessel skill (not one of the 4 defaults);
# selectable in the campaign loadout. Cost/cooldown/classes/target_type come from abilities_data.json.

func describe(user):
	return ""

func split_desc():
	return [
		["Stun target enemy for 1 turn", Color.MEDIUM_PURPLE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(2)   # 2 == 1 turn
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context, 0)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
