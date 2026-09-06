extends Ability



#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to one enemy. Deals 5 additional damage for every stack of Shadow Clones."

func split_desc():
	return [
		"Deals 35 damage to target enemy and increases the cost of their skills by 1 Random energy for 2 turns"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 35, DamageType.Type.NORMAL)
		var effect = Effect.cost_mod_effect(1, 4, Energy.Type.RANDOM)
		effect.set_source(self)
		Character.add_hostile_effect(context, user, target, effect)
	
	if user.has_effect("Sage Chakra Gather", EffectType.Type.MARK):
		user.effects.remove_effect(user.has_effect("Sage Chakra Gather", EffectType.Type.MARK))

	
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
