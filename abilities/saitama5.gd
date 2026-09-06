extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The enemy marked by 'Serious Series: Serious Side-Hops' is instantly killed. Uncounterable, unreflectable."

func split_desc():
	return [
		"Instantly kills the enemy marked by Serious Series: Serious Side-Hops"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		target.instant_kill(user, self)
		
func extra_usable(user):
	var context = QueryContext.from_game_state(user, user.battle)
	for character in user.battle.all_characters():
		var marked = Condition.has_effect(character, "Serious Series: Serious Side-Hops", EffectType.Type.MARK, user)
		if marked.satisfied(context):
			return true
	return false

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_single_require_mark(context, "Serious Series: Serious Side-Hops", EffectType.Type.MARK, 50)
	
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		var marked = Condition.has_effect(character, "Serious Series: Serious Side-Hops", EffectType.Type.MARK, user)
		if marked.satisfied(context):
			check_hostile_target(user, character, context)
