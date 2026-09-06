extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tanjiro deals 25 damage to all enemies. Swaps with Seventh Form: Drop Ripple Thrust."

func split_desc():
	return [
		"Deals 25 damage to all enemies",
		["Swaps with Seventh Form: Drop Ripple Thrust", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var damage_type = DamageType.Type.NORMAL
		var countered = Condition.has_effect(target, "Seventh Form: Drop Ripple Thrust", EffectType.Type.VULNERABILITY, user)
		if countered.satisfied(context):
			damage_type = DamageType.Type.PIERCING
		Character.resolve_damage(context, target, base_damage, damage_type)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
