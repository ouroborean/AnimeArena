extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 Piercing damage to one enemy. If the target drops to 15HP or below they will be executed. Bypasses invulnerability."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy (Bypassing)",
		["Targets at or below 15 HP afterward will be executed", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
		target.execute_attempt(15, user, self)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75, 2.0)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
