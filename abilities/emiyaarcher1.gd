extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 True damage to target enemy 2 times. This skill counts as 2 skill uses",
		["While Empowered, strikes 3 times and counts as 3 skill uses.", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.marked_by("Grand Caladbolg"):
		for target in user.targeter.targets:
			Character.resolve_damage(context, target, 40, DamageType.Type.TRUE)
			var mark = user.has_effect("Grand Caladbolg", EffectType.Type.MARK)
			user.effects.erase_effect(mark)
	else:
		for target in user.targeter.targets:
			Character.resolve_damage(context, target, 10, DamageType.Type.TRUE)
			Character.resolve_damage(context, target, 10, DamageType.Type.TRUE)
			if user.marked_by("Hawkeye"):
				user.manually_advance_mission(8, 1)
				Character.resolve_damage(context, target, 10, DamageType.Type.TRUE)
		user.check_ability_use_triggers(user.battle, self, true)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
