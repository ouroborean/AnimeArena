extends Ability

func describe(user):
	return "Impmon heals for 50% of all damage he deals."

func split_desc():
	return [
		["Impmon heals for 50% of all damage he deals, from any source", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Permanent self-marker read by Character.deal_ability_damage / deal_effect_damage, which
	# lifesteal mark.mag% (50%) of ALL damage Impmon deals. The marker name == this ability's
	# name ("Lord of Gluttony"), which the damage pipeline keys on.
	var mark = Effect.mark(-1, "Impmon heals for 50% of all damage he deals.")
	mark.mag = 50
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
