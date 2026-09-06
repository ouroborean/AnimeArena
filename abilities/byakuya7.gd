extends Ability
var base_damage = 90
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 90 Piercing damage split between all living enemies. Bypasses invulnerability."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, (base_damage/len(user.targeter.targets)), DamageType.Type.PIERCING)


func split_desc():
	return [
		"Deals 90 Piercing damage split between all living enemies (Bypassing)"
	]
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []

	variations += behavior_hostile_aoe_damage(context, 40)

	return variations

func bot_damage_hint() -> float:
	# Splits base_damage across all living enemies; assume 3-way for per-target hint.
	return base_damage / 3.0
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)

