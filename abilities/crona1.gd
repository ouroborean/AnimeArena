extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 5 Affliction damage to Crona and 10 Affliction damage to all enemies",
		["Increases the cost of Crona's skills by 1 energy of a randomly chosen color for the following turn", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var total_cost = 0
	var captured_cost = cost()
	for cost_type in captured_cost:
		total_cost += captured_cost[cost_type]
	Character.resolve_damage(context, user, 5, DamageType.Type.AFFLICTION)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.AFFLICTION)
	
	var energy_color = user.battle.roll(0, 3)
	var energy_mod = Effect.cost_mod_effect(1, 3, energy_color)
	energy_mod.set_source(self)
	Character.add_allied_effect(context, user, user, energy_mod)
	user.manually_advance_mission(6, total_cost)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 15)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
