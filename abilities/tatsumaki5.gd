extends Ability
var base_damage = 75
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Targets a currently stunned character, dealing 75 damage to them."

func split_desc():
	return [
		"Deals 75 damage to a currently stunned enemy"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
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
	var context = QueryContext.from_game_state(user, battle)
	for character in context['enemy_team'].characters:
		if not (character.dead or character.banished) and character.has_stuns():
			check_hostile_target(user, character, context, true)
	
