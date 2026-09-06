extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "At the start of combat, the ally directly below Uranus is permanently marked with Uranus Lip Rod. While marked, that ally gains 5 Damage Reduction."

func split_desc():
	return [
		"At combat start, the ally directly below Uranus is permanently marked with Uranus Lip Rod",
		["That ally gains 5 Damage Reduction permanently while marked", Color.CADET_BLUE]
	]

func execute(user, battle):
	# Passive — fires once at battle start via Character.startup_passives.
	# "Directly below" maps to the team.characters slot at uranus_index + 1.
	# If Uranus is the last character in the slot order (index == size - 1),
	# there's no ally below and the passive is a no-op for this match.
	var context = QueryContext.from_game_state(user, battle)
	var team_chars = user.team.characters
	var uranus_index = team_chars.find(user)
	if uranus_index < 0 or uranus_index >= len(team_chars) - 1:
		return
	var ally = team_chars[uranus_index + 1]
	if ally == null:
		return

	# Permanent mark (visible) so the other Uranus skills can locate this
	# ally via marked_by("Uranus Lip Rod", user).
	var mark = Effect.mark(-1, "Marked by Uranus Lip Rod. Sailor Uranus's skills use this ally as their support target.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, user, ally, mark)

	# The promised 5 DR, also permanent and also sourced from this passive.
	var dr = Effect.damage_reduction_effect(5, -1)
	dr.set_source(self)
	dr.cleansable = false
	Character.add_allied_effect(context, user, ally, dr)

func extra_usable(user):
	return true

func target(user, battle):
	pass
