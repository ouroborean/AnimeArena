extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Megumi becomes Invulnerable to non-Physical skills for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shikigami = user.has_effect("Shikigami Summoning", EffectType.Type.TICKING_TRIGGER)
	var target_class
	if not shikigami:
		target_class = "Physical"
	else:
		target_class = shikigami.mag
	var invuln = Effect.invuln_effect(2, [], [target_class])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 30)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
