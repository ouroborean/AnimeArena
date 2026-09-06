extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sakura targets an enemy for 1 turn, counters them if they use a new harmful skill, and gains 1 random energy if successful."

func split_desc():
	return [
		"Reduces target enemy's Damage Reduction effects to 0, then deals 20 damage to them"
	]


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		for effect in target.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION):
			effect.mag = 0
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 50)
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
