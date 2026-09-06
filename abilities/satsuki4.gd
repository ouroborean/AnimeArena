extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Satsuki becomes invulnerable for 1 turn. If Satsuki is at full health, this skill has a 2 turn reduced cooldown."

func split_desc():
	return [
		["Satsuki becomes invulnerable for 1 turn", Color.CADET_BLUE],
		["If Satsuki is at full health, this skill has a 2 turn reduced cooldown", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	user.manually_advance_mission(9, 1)
	if user.health.hp >= 100:
		cooldown_remaining = 2
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var superiority_mod = 0
	if user.health.hp >= 100:
		superiority_mod += 50
	variations += behavior_self_panic_button(context, 35 + superiority_mod, 1.2)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
