extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Tokoyami becomes Invulnerable to Strategic skills for 1 turn",
		["This also affects Mental skills, non-Mental skills, and Tokoyami's allies if he has 1, 2, or 3 stacks of Black Abyss", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mag = 0
	if user.has_effect("Black Abyss", EffectType.Type.MARK):
		mag = user.has_effect("Black Abyss", EffectType.Type.MARK).mag
	if mag == 3:
		user.manually_advance_mission(8, 1)
	for target in user.targeter.targets:
		match mag:
			0:
				var invuln = Effect.invuln_effect(2, ["Strategic"])
				invuln.set_source(self)
				Character.add_allied_effect(context, user, target, invuln)
			1:
				var invuln = Effect.invuln_effect(2, ["Strategic", "Mental"])
				invuln.set_source(self)
				Character.add_allied_effect(context, user, target, invuln)
			2:
				var invuln = Effect.invuln_effect(2)
				invuln.set_source(self)
				Character.add_allied_effect(context, user, target, invuln)
			3:
				var invuln = Effect.invuln_effect(2)
				invuln.set_source(self)
				Character.add_allied_effect(context, user, target, invuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []

	var mag = 0
	if user.has_effect("Black Abyss", EffectType.Type.MARK):
		mag = user.has_effect("Black Abyss", EffectType.Type.MARK).mag
	
	if mag != 3:
		variations += behavior_self_panic_button(context, 15)
	else:
		variations += behavior_helpful_aoe_aid(context, 40)
	return variations

	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var mag = 0
	if user.has_effect("Black Abyss", EffectType.Type.MARK):
		mag = user.has_effect("Black Abyss", EffectType.Type.MARK).mag
	if mag != 3:
		default_self_target_function(user, battle)
	else:
		default_allied_target_function(user, battle)
