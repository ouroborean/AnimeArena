extends Ability
var base_power = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Hashirama heals his team for 20 HP and deals 20 Affliction damage to the enemy team. This skill is delayed by 1 turn. While enhanced, this skill will heal Hashirama's team for 5 HP and deal 5 Affliction damage to the enemy team each turn that it remains delayed."

func split_desc():
	return [
		"Heals Hashirama's team for 20 HP",
		"Deals 20 Affliction damage to all enemies",
		["Delayed by 1 turn", Color.DIM_GRAY],
		["While enhanced, also heals his team 5 HP and deals 5 Affliction damage to all enemies each turn it stays delayed", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	if user.marked_by("Deep Forest Creation", user):
		user.manually_advance_mission(9, 1)

	for target in user.targeter.targets:
		if target in user.team.characters and not target.dead and not target.banished:
			Character.resolve_healing(context, target, base_power)
		else:
			Character.resolve_damage(context, target, base_power, DamageType.Type.AFFLICTION)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true


func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
