extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Frankenstein self-destructs, dealing damage equal to her missing HP in Piercing damage to target enemy."

func split_desc():
	return [
		"Deals Piercing damage to target enemy equal to how much HP Frankenstein is missing",
		"Afterwards, Frankenstein dies"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var damage = 100 - user.health.hp
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, DamageType.Type.PIERCING)
	
	user.instant_kill(user, self)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	if user.health.hp <= 30:
		variations += behavior_single_target_damage(context, -30, 0.8)
	else:
		variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
