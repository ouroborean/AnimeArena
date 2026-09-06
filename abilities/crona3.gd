extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to target enemy and Taunts them",
		["Lasts 1 turn for each energy spent on this skill", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var total_cost = 0
	var captured_cost = cost()
	for cost_type in captured_cost:
		total_cost += captured_cost[cost_type]
	var duration = 1 + (total_cost * 2)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var damage_eff = Effect.damage_effect(10, DamageType.Type.NORMAL, duration)
		damage_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_eff)
		var taunt = Effect.taunt_effect(duration - 1, user)
		taunt.set_source(self)
		Character.add_hostile_effect(context, user, target, taunt)
	user.manually_advance_mission(6, total_cost)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 10)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if not character.has_effect("Scream Assault", EffectType.Type.DAMAGE, user):
			check_hostile_target(user, character, context, false)
