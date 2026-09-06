extends Ability
var base_damage = 20
var damage_inc = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 piercing damage to one enemy. This deals 5 more damage for each stack of his passive already on him."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy",
		"+5 damage per stack of Branch of Sin: Woodpecker"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var blood_stacks = 0
	var damage_effects = user.get_effects_by_type(EffectType.Type.DAMAGE)
	for effect in damage_effects:
		if effect.source.ability_name == "Branch of Sin: Woodpecker":
			blood_stacks += 1
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + (damage_inc * blood_stacks), DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		var bypass = false
		if character.effects.has_effect("Reckless Rush", EffectType.Type.MARK, user):
			bypass = true
		check_hostile_target(user, character, context, bypass)
