extends Ability

var base_damage = 30

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to one enemy and stuns their physical, mental, and strategic skills for 1 turn."

func split_desc():
	return [
		"Reduces all enemies' Damage Reduction effects to 0, then deals 30 damage to them"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		for effect in target.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION):
			effect.mag = 0
		Character.resolve_damage(context, target, 30, DamageType.Type.NORMAL)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
