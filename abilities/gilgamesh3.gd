extends Ability
var base_damage = 35

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 35 piercing damage to one enemy and for 1 turn, that enemy's skills and effects do not deal damage or healing."


func split_desc():
	return [
		"Deals 35 Piercing damage to target enemy",
		"Affected enemies cannot cause damage or healing for 1 turn",
	]
	


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var chain = Effect.from(EffectType.Type.CHAIN_NULLIFY, {"description": "This character's skills and effects cannot cause damage or healing.", "duration": 3})
		chain.set_source(self)
		Character.add_hostile_effect(context, user, target, chain)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 50, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
