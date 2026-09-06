extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""
	
func split_desc():
	return [
		"Deals 35 damage to target enemy, consuming up to 2 stacks of Guts",
		["+10 damage if at least 1 stack consumed", Color.DIM_GRAY],
		["Stuns the target's non-Strategic skills for 1 turn if at least 2 stacks consumed", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var consumed_stacks = user.call_unique("gunha", "expend_guts", [2])
	if consumed_stacks == null:
		consumed_stacks = 0
	for target in user.targeter.targets:
		var base_damage = 35
		if consumed_stacks >= 1:
			base_damage += 10
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		if consumed_stacks >= 2:
			var stun = Effect.stun_effect(2, [], ["Strategic"])
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
