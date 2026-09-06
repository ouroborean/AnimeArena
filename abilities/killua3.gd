extends Ability
var base_damage = 15
var execute_threshold = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Killua detonates all Decapitation Counters on an enemy, dealing 15 affliction damage for each counter detonated. Affected enemies are Executed if their health falls to 20 or below."

func split_desc():
	return [
		"Detonates all stacks of Decapitation on target enemy",
		"Deals 15 Affliction damage per stack detonated",
		["Executes the enemy if their health falls to 20 or below", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if not target.has_effect("Decapitation", EffectType.Type.MARK):
			continue
		var stack_count = target.has_effect("Decapitation", EffectType.Type.MARK, user).stack_count()
		Character.resolve_damage(context, target, base_damage * stack_count, DamageType.Type.AFFLICTION)
		target.execute_attempt(execute_threshold, user, self)
		
		
func extra_usable(user):
	var context = QueryContext.from_game_state(user, user.battle)
	for character in user.battle.all_characters():
		var marked = Condition.has_effect(character, "Decapitation", EffectType.Type.MARK, user)
		if marked.satisfied(context):
			return true
	return false

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_single_require_mark(context, "Decapitation", EffectType.Type.MARK, 40, true)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		var marked = Condition.has_effect(character, "Decapitation", EffectType.Type.MARK, user)
		if marked.satisfied(context):
			check_hostile_target(user, character, context)
			
