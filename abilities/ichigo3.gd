extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "After Ichigo uses 5 skills, he will release his Bankai, replacing all of his skills with their Bankai versions permanently." 

func split_desc():
	return [
		"Ichigo becomes Invulnerable for 1 turn and on the following turn, his Harmful skill are enhanced and cost 1 less Random energy",
		["Cooldown increases by 1 with each use", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	var cost_down = Effect.cost_mod_effect(-1, 3, Energy.Type.RANDOM, ["Zangetsu Slash", "Getsuga Tenshou"])
	cost_down.set_source(self)
	Character.add_allied_effect(context, user, user, cost_down)
	
	var target_change = Effect.target_change_effect(TargetType.Type.ALL, 3, ["Zangetsu Slash"])
	target_change.set_source(self)
	Character.add_allied_effect(context, user, user, target_change)
	
	var mark = Effect.mark(3, "Getsuga Tenshou will Bypass and deals 10 more damage.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	
	var portrait = Effect.portrait_change_effect(0, 3)
	portrait.set_source(self)
	Character.add_allied_effect(context, user, user, portrait)
	
	cooldown += 1


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	default_self_target_function(user, battle)
