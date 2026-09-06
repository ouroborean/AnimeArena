extends Ability
var base_damage = 15
var base_boost = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 piercing damage to one enemy. If Satsuki is at full health, this ability deals 10 additional damage."

func split_desc():
	return [
		"Deals 15 Piercing damage to one enemy",
		["+10 damage if Satsuki is at full health", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	for target in user.targeter.targets:
		var mod_damage = base_damage
		if user.health.hp >= 100:
			mod_damage += base_boost
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var superiority_mod = 0
	if user.health.hp >= 100:
		superiority_mod += 50
	variations += behavior_single_target_damage(context, superiority_mod)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
