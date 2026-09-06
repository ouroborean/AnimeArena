extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Megumin fully cleanses herself of enemy effects, and removes the lingering effect from Explosion",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var count = user.effects.cleanse_all_enemy_effects(user)
	user.manually_advance_mission(9, 1)
	if user.marked_by("Explosion"):
		user.effects.erase_effect(user.has_effect("Explosion", EffectType.Type.MARK))
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
