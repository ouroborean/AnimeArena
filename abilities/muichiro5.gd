extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 Piercing damage to all enemies for 3 turns",
		["While active, Tokito has double the chance to dodge skills via Seventh Form: Obscuring Clouds", Color.CADET_BLUE]
	]
func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.PIERCING)
		var tick = Effect.damage_effect(10, DamageType.Type.PIERCING, 5)
		tick.set_source(self)
		Character.add_hostile_effect(context, user, target, tick)
	var mark = Effect.mark(5, "Tokito has double chance to dodge via Seventh Form: Obscuring Clouds.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
