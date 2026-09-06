extends Ability

var base_threshold = 25
var threshold_increment = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Gon Freecss executes an enemy at 25HP or below. If Gon has stacks of Jajanken Stance, this skill will first deal 10 damage for every stack of 'Jajanken Stance' Gon has."

func split_desc():
	return [
		"Executes target enemy at 25 or less HP",
		"First deals 0 damage if Jajanken Stance is active"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var jajanken = Condition.has_effect(user, "Jajanken Stance", EffectType.Type.DAMAGE_MOD, user)
	
	var threshold_boost = 0
	if jajanken.satisfied(context):
		threshold_boost += (user.effects.has_effect("Jajanken Stance", EffectType.Type.DAMAGE_MOD, user).stack_count() * 10)
	
	for target in user.targeter.targets:
		if threshold_boost > 0:
			Character.resolve_damage(context, target, threshold_boost, DamageType.Type.NORMAL)
		target.execute_attempt(base_threshold, user, self)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():

		var threshold = base_threshold
		if character.health.hp <= threshold:
			check_hostile_target(user, character, context)
