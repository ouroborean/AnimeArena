extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "If Soul Evans is on Maka's team, Soul Resonance always costs nothing, cannot be stunned, and can only target him."

func split_desc():
	return [
		["While Soul Evans is on Maka's team, Soul Resonance costs nothing and cannot be stunned", Color.CADET_BLUE],
		["Soul Resonance can only target Soul Evans", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in user.team.characters:
		if character.path_name == "soul":
			var cost_change = Effect.cost_change_effect({}, -1, ["Soul Resonance"])
			cost_change.set_source(self)
			cost_change.description = func (eff):
				return "Soul Resonance costs nothing, cannot be stunned, and can only target Soul Evans."
			cost_change.cleansable = false
			Character.add_allied_effect(context, user, user, cost_change)
			user.moveset.base_abilities[1].stunnable = false
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	pass
