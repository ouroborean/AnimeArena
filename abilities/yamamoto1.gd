extends Ability
var base_damage = 20
var base_weakness = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to one enemy, and lowers their damage by 10 for 2 turns (refreshes). Yamamoto gains 1 stack of Asari Ugetsu."

func split_desc():
	return [
		"Deals 20 damage to one enemy",
		["Lowers their damage by 10 for 2 turns (refreshes)", Color.ORANGE_RED],
		["Yamamoto gains 1 stack of Asari Ugetsu", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var weakness = Effect.damage_mod_effect(-10, 4)
		weakness.refresh = true
		weakness.set_source(self)
		Character.add_hostile_effect(context, user, target, weakness)
		user.call_unique("yamamoto", "gain_flames", [1])
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 45)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
