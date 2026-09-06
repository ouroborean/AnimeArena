extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 15 damage to target enemy and stuns their Strategic skills for 1 turn",
		["Also stuns the target's Mental skills, non-Mental skills, and their allies' skills if Tokoyami has 1, 2, or 3 stacks of Black Abyss", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mag = 0
	if user.has_effect("Black Abyss", EffectType.Type.MARK):
		mag = user.has_effect("Black Abyss", EffectType.Type.MARK).mag
	if mag == 3:
		user.manually_advance_mission(8, 1)
	for target in user.targeter.targets:
		if target == user.targeter.targets[0]:
			Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
		match mag:
			0:
				var stun = Effect.stun_effect(2, ["Strategic"])
				stun.set_source(self)
				Character.add_hostile_effect(context, user, target, stun)
			1:
				var stun = Effect.stun_effect(2, ["Strategic", "Mental"])
				stun.set_source(self)
				Character.add_hostile_effect(context, user, target, stun)
			2:
				var stun = Effect.stun_effect(2)
				stun.set_source(self)
				Character.add_hostile_effect(context, user, target, stun)
			3:
				var stun = Effect.stun_effect(2)
				stun.set_source(self)
				Character.add_hostile_effect(context, user, target, stun)
		
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
		variations += behavior_single_target_damage(context, 25)
	else:
		variations += behavior_hostile_aoe_damage(context, 40)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
