extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For one turn, Shinra's damaging skills will cost one less Green energy and apply 5 permanent affliction damage."

func split_desc():
	return [
		["For 1 turn, Shinra's damaging skills cost 1 less Green energy and apply 5 permanent affliction damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var color_change = Effect.cost_mod_effect(-1, 3, Energy.Type.GREEN, ["Rapid Kick", "Tora Hishigi"])
	color_change.set_source(self)
	var mark = Effect.mark(3, "Rapid Kick and Tora Hishigi will apply 5 permanent affliction damage to their target.")
	mark.set_source(self)
	user.manually_advance_mission(10, 1)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, color_change)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Ignition: Shinra", user)
	
func custom_behavior(context):
	var variations = []
	variations.append([175, [user, self, []]])
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
