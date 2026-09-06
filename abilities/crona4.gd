extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Crona gets 0 Damage Reduction and 0 Shield for 3 turns",
		["Grants +5 Damage Reduction and Shield for each energy spent on this skill", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var total_cost = 0
	var captured_cost = cost()
	for cost_type in captured_cost:
		total_cost += captured_cost[cost_type]
	var mag = 5
	mag = mag * total_cost
	var shield = Effect.shield_effect(int(mag), 6)
	shield.set_source(self)
	var dr = Effect.damage_reduction_effect(int(mag), 6)
	dr.set_source(self)
	dr.unique_render_id = 69
	dr.display_mag = true
	Character.add_allied_effect(context, user, user, shield)
	Character.add_allied_effect(context, user, user, dr)
	user.manually_advance_mission(6, total_cost)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
