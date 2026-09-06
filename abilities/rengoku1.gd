extends Ability

var base_damage = 20

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 Piercing damage to the target and Shatters them until the end of Rengoku's next turn. If the target is already Shattered, Shatter them for an extra turn."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy",
		"Shatters them until the end of Rengoku's next turn",
		["Shatters them for an extra turn if already Shattered", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var duration = 3
		if len(target.effects.get_effects_by_type(EffectType.Type.DEF_NEGATE)) > 0:
			duration += 2
		var shatter = Effect.def_negate(duration)
		shatter.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 60, 1.1)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
