extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever Aang uses a skill matching his current elemental alignment, he cycles to the next elemental alignment in the following sequence: Air -> Water -> Earth -> Fire. When he completes the cycle, he gains Aang Avatar State."

func split_desc():
	return [
		"Changes Aang's Elemental Alignment whenever he uses a skill that matches his current alignment",
		"Aang changes Elemental Alignment in the following order: Air -> Water -> Earth -> Fire",
		"Aang starts each game Air-Aligned."
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var exp_desc = func (eff):
		return "If Aang uses a skill matching his current elemental alignment, he will advance his Avatar State."
	var mark_desc = func (eff):
		var string = ""
		if eff.mag == 0:
			string = "Air"
		elif eff.mag == 1:
			string = "Water"
		elif eff.mag == 2:
			string = "Earth"
		elif eff.mag == 3:
			string = "Fire"
		return "Aang is currently " + string + "-aligned."
	var exp_eff = Effect.empty(-1, exp_desc)
	exp_eff.set_source(self)
	var mark_eff = Effect.mark(-1, mark_desc)
	mark_eff.set_source(self)
	mark_eff.mag = 0
	mark_eff.cleansable = false

	Character.add_allied_effect(context, user, user, exp_eff)
	Character.add_allied_effect(context, user, user, mark_eff)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	pass
