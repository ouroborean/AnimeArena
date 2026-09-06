extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 3 turns, all enemies deal 5 less non-Affliction damage, consuming up to 2 stacks of Guts",
		["Shatters affected enemies if 1 stack consumed", Color.DIM_GRAY],
		["Affected enemies take 5 more non-Affliction damage if 2 stacks consumed", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var consumed_stacks = user.call_unique("gunha", "expend_guts", [2])
	if consumed_stacks == null:
		consumed_stacks = 0
	for target in user.targeter.targets:
		var mod = Effect.damage_mod_effect(-5, 6, [], [], [DamageType.Type.AFFLICTION])
		mod.set_source(self)
		Character.add_hostile_effect(context, user, target, mod)
		if consumed_stacks >= 1:
			var shatter = Effect.def_negate(5)
			shatter.set_source(self)
			Character.add_hostile_effect(context, user, target, shatter)
		if consumed_stacks >= 2:
			var vuln = Effect.vulnerability_effect(5, 5, [], [], [DamageType.Type.AFFLICTION])
			vuln.set_source(self)
			Character.add_hostile_effect(context, user, target, vuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
