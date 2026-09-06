extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ophanimon deals 10 damage 9 times to random enemies. Bypasses Invulnerability."

func split_desc():
	return [
		"Deals 10 damage to 9 random enemies (Bypassing)"
	]
	

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var potential_targets = []
	for enemy in context['enemy_team'].characters:
		if not (enemy.dead or enemy.banished):
			potential_targets.append(enemy)
	
	if len(potential_targets) > 0:
		for i in range(9):
			var roll = battle.roll(0, len(potential_targets) - 1)
			var chosen_enemy = potential_targets[roll]
			Character.resolve_damage(context, chosen_enemy, base_damage, DamageType.Type.NORMAL)
	
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 35, 1.1)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
