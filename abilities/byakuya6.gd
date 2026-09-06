extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 Piercing damage to target enemy."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		if target.has_effect("Bakudo #61: Six-Rod Light Restraint", EffectType.Type.DEF_NEGATE) or target.has_effect("Bakudo #61: Six-Rod Light Restraint", EffectType.Type.STUN):
			user.manually_advance_mission(6, 1)
		
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)

func split_desc():
	return ["Deals 20 Piercing damage to target enemy"]

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
