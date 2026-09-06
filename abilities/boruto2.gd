extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Boruto gains 30 Shield for 4 turns",
		["During this time, Karma Taijutsu lasts 1 more turn and Rasengan skills cost 1 less Random energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var shield = Effect.shield_effect(30, 8)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	var mark = Effect.mark(9, "Karma Taijutsu lasts 1 more turn.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	var cost_mod = Effect.cost_mod_effect(-1, 9, Energy.Type.RANDOM, ["Vanishing Rasengan", "Compression Rasengan", "Wind Release: Rasengan"])
	cost_mod.set_source(self)
	Character.add_allied_effect(context, user, user, cost_mod)
	
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 45)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
