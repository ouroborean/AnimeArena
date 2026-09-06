extends Ability

var base_damage = 30

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to one enemy and grants Zoro 10 Shield for 1 turn."

func split_desc():
	return [
		"Deals 30 damage to one enemy",
		["Zoro gains 10 Shield for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.NORMAL)
	var shield_eff = Effect.shield_effect(10, 2)
	shield_eff.set_source(self)
	Character.add_allied_effect(context, user, user, shield_eff)
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
