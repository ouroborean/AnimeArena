extends Ability
var base_main_damage = 45
var base_aoe_damage = 25
var base_ally_damage = 15

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ganta deals 45 damage to one enemy, then 25 damage to all enemies, and then 15 damage to his entire team. This skill is only usable if Ganta is at 10 health or below. This threshold increases by 5 for each stack of his passive that is active on Ganta."

func split_desc():
	return[
		"Deals 45 damage to target enemy, then 25 damage to all enemies, then 15 damage to all allies",
		"Only usable if Ganta's HP is 10 or less",
		"Threshold increases by 5 per stack of Branch of Sin: Woodpecker"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	Character.resolve_damage(context, user.targeter.main_target, base_main_damage, DamageType.Type.NORMAL)
	
	for target in user.targeter.targets:
		var hostile = Condition.is_hostile(user, target)
		if hostile.satisfied(context):
			Character.resolve_damage(context, target, base_aoe_damage, DamageType.Type.NORMAL)
	for target in user.team.characters:
		Character.resolve_damage(context, target, base_ally_damage, DamageType.Type.NORMAL)
	
		
func extra_usable(user):
	var stacks = 0
	var damage_effects = user.get_effects_by_type(EffectType.Type.DAMAGE)
	for effect in damage_effects:
		if effect.source.ability_name == "Branch of Sin: Woodpecker":
			stacks += 1
	var threshold = 10 + (5 * stacks)
	return user.health.hp <= threshold

func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 40, false)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		var bypass = false
		if character.effects.has_effect("Reckless Rush", EffectType.Type.MARK, user):
			bypass = true
		check_hostile_target(user, character, context, bypass)
