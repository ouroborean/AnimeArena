extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Usopp's attacks cannot Miss or be Dodged, and he ignores Blind effects."

func split_desc():
	return [
		["Usopp's attacks cannot Miss or be Dodged, and he ignores Blind effects", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var sharpshooter = Effect.sharpshooter(-1)
	sharpshooter.set_source(self)
	sharpshooter.cleansable = false
	var ignore = Effect.ignore_effect_effect(-1, EffectType.Type.BLIND)
	ignore.set_source(self)
	ignore.cleansable = false
	Character.add_allied_effect(context, user, user, sharpshooter)
	Character.add_allied_effect(context, user, user, ignore)
	
		
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
	pass
