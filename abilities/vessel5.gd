extends Ability

# Second Wind — the Vessel heals itself 15 HP. An ALTERNATE Vessel skill (not one of the 4 defaults);
# selectable in the campaign loadout. Cost/cooldown/classes/target_type come from abilities_data.json.

var base_healing = 15

func describe(user):
	return ""

func split_desc():
	return [
		["Heal yourself 15 HP", Color.LIGHT_GREEN],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	Character.resolve_healing(context, user, base_healing)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, base_healing)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
