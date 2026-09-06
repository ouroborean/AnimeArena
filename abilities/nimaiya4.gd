extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, Oetsu ignores all harmful effects. Invisible."

func split_desc():
	return [
		"For 1 turn, Oetsu ignores all Harmful effects",
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var non_damage = Effect.ignore_non_damage_effect(2)
		var damage = Effect.ignore_damage_effect(2)
		non_damage.invisible=true
		damage.invisible=true
		damage.wrapup_func = default_counter_timeout
		non_damage.set_source(self)
		damage.set_source(self)
		Character.add_allied_effect(context, user, user, non_damage)
		Character.add_allied_effect(context, user, user, damage)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 35, 1.2)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
