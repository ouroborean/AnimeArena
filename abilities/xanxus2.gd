extends Ability

var base_damage = 35
var base_splash = 20

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 35 damage to one enemy. This skill gains the following bonus effects, corresponding to the effects that have triggered Scars of Wrath: Been Countered -> Uncounterable. Been reduced below half health -> Deals 20 damage to other enemy targets."

func split_desc():
	return [
		"Deals 35 damage to one enemy",
		["Scars of Wrath (countered triggered): Uncounterable", Color.CADET_BLUE],
		"Scars of Wrath (below half health triggered): Deals 20 damage to other enemy targets"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target == user.targeter.main_target:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		else:
			Character.resolve_damage(context, target, base_splash, DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	if target_type() == TargetType.Type.ALL:
		variations += behavior_hostile_aoe_damage(context, 40, 1.1)
	else:
		variations += behavior_single_target_damage(context, 45, 0.9)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
