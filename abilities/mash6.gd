extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mash increases the remaining Shield on A Knight That Protects by 25, up to a maximum of 40."

func split_desc():
	return [
		"Increases the remaining Shield on A Knight That Protects by 25 (up to 40)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shield = user.has_effect("A Knight That Protects", EffectType.Type.SHIELD, user)
	if not shield:
		return
	shield.mag += 25
	if shield.mag > 40:
		shield.mag = 40
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 70)
	
	return variations
	
func target(user, battle):

	default_self_target_function(user, battle)
