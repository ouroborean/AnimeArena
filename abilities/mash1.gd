extends Ability
var base_damage = 15
var bonus = 10
var threshold = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 damage to target enemy, increased by 10 for each 20 Shield currently on Mash. After A Knight That Protects ends, this skill becomes Around Round Axe for 1 turn."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var shields = user.get_shield_effects()
	var total_shielding = 0
	var shield_broken = user.ignoring_effect_type(EffectType.Type.SHIELD)
	if not shield_broken:
		for shield in shields:
			total_shielding += shield.mag
	var multipliers = total_shielding / threshold
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + (bonus * multipliers), DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
