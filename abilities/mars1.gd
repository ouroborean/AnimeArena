extends Ability
var base_power = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Targets a character marked by Ofuda. If they are an enemy, they receive 10 damage, increased by 5 per character marked by Ofuda. If they are an ally, they are healed for 10 HP, increased by 5 per character marked by Ofuda."

func split_desc():
	return [
		["If used on an enemy marked by Ofuda, deals 10 damage (+5 per character marked by Ofuda)", Color.ORANGE_RED],
		["If used on an ally marked by Ofuda, heals 10 HP (+5 per character marked by Ofuda)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var ofuda_stacks = 0
	for character in battle.all_characters():
		if character.marked_by("Ofuda", user) and not (character.dead or character.banished):
			ofuda_stacks += 1
	
	
	for target in user.targeter.targets:
		if target in user.team.characters:
			Character.resolve_healing(context, target, base_power + 5 * ofuda_stacks)
		else:
			Character.resolve_damage(context, target, base_power + 5 * ofuda_stacks, DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_single_require_mark(context, "Ofuda", EffectType.Type.MARK, 15)
	variations += behavior_helpful_single_require_mark(context, "Ofuda", EffectType.Type.MARK, 15)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, false, "Ofuda")
	default_allied_target_function(user, battle, false, "Ofuda")
