extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, the enemy team is Shattered, Blinded, and take 5 additional damage from all sources. 'Rocket Boosters' has its cooldown reset and is improved for 1 turn."


func split_desc():
	return [
		"Blinds and Shatters all enemies for 1 turn",
		"Affected enemies get +5 damage taken"
	]
	


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var shatter_eff = Effect.def_negate(2)
		shatter_eff.set_source(self)
		var blind_eff = Effect.blind_effect(2)
		blind_eff.set_source(self)
		var vuln_eff = Effect.vulnerability_effect(5, 3)
		vuln_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter_eff)
		Character.add_hostile_effect(context, user, target, blind_eff)
		Character.add_hostile_effect(context, user, target, vuln_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25, 0.8)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
