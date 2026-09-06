extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Saturn marks target character for the next 3 turns",
		["When the mark expires, targeted enemies are executed and targeted allies are returned to full HP", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			var mark = Effect.mark(7, "When this effect expires, this character will return to 100 HP.")
			mark.set_source(self)
			mark.wrapup_func = allied_wrapup_func
			Character.add_allied_effect(context, user, target, mark)
		else:
			var mark = Effect.mark(7, "When this effect expires, this character will be executed.")
			mark.set_source(self)
			mark.wrapup_func = hostile_wrapup_func
			Character.add_hostile_effect(context, user, target, mark)
	

func hostile_wrapup_func(context):
	context.target.instant_kill(user, self)
	user.manually_advance_mission(8, 1)

func allied_wrapup_func(context):
	context.target.health.set_health(context.target.get_modified_max_hp())
	user.manually_advance_mission(8, 1)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 100)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
