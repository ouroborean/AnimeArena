extends Ability

func describe(user):
	return "If Alphamon's skills are countered, he regains the energy spent on them and heals 15 HP."

func split_desc():
	return [
		"If Alphamon's skills are countered, he regains the energy spent on them and heals 15 HP.",
	]

func execute(user, battle):
	var mark = Effect.mark(-1, "If Alphamon's skills are countered, he gains energy equal to the cost of the skill and heals 15 HP.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(make_context(battle), user, user, mark)

func extra_usable(user):
	return false

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	pass
