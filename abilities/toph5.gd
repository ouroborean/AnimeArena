extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Toph ignores Blind effects and enemy Physical effects are always visible"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var effect_ignore = Effect.ignore_effect_effect(-1, EffectType.Type.BLIND)
	effect_ignore.set_source(self)
	effect_ignore.cleansable = false
	Character.add_allied_effect(context, user, user, effect_ignore)
	var mark = Effect.mark(-1, "Toph can see Invisible Physical effects.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, user, user, mark)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
