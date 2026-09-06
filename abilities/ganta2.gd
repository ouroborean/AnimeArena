extends Ability
var base_damage = 10
var boost_inc = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 piercing damage to one enemy. This skill deals 5 more damage per 20 health Ganta is missing and 5 more damage per 20 health the target is missing."

func split_desc():
	return [
		"Deals 10 Piercing damage to target enemy",
		"+5 damage per 20 HP Ganta is missing",
		"+5 damage per 20 HP target is missing"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var anemia_boosts = (100 - user.health.hp) / 20
	for target in user.targeter.targets:
		var weakness_boosts = (100 - target.health.hp) / 20
		Character.resolve_damage(context, target, base_damage + (anemia_boosts * boost_inc) + (weakness_boosts * boost_inc), DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		var bypass = false
		if character.effects.has_effect("Reckless Rush", EffectType.Type.MARK, user):
			bypass = true
		check_hostile_target(user, character, context, bypass)
