extends Ability
var base_damage = 35
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ichigo makes his team invulnerable to non-mental skills for 1 turn and deals 35 Piercing damage to all enemies."

func split_desc():
	return [
		"Deals 35 Piercing damage to all enemies",
		["Ichigo's team becomes invulnerable to non-Mental skills for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hostile = Condition.is_hostile(user, target)
		if hostile.satisfied(context):
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		else:
			var invuln = Effect.invuln_effect(2, [], ["Mental"])
			invuln.set_source(self)
			Character.add_allied_effect(context, user, target, invuln)
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 15)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
