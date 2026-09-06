extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Meliodas equips the Dragon Hilt, lowering the cost of Hellblaze to 1 random energy and reducing the cooldown of Full Counter by 1 turn. This skill is replaced by Lostvayne."

func split_desc():
	return [
		"Deals 15 Affliction to target enemy",
		["Affected enemies take 5 Affliction damage on the following turn and ignore healing for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var base_damage = 15
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.AFFLICTION)
		
		var heal_ignore = Effect.ignore_healing(2)
		heal_ignore.set_source(self)
		Character.add_hostile_effect(context, user, target, heal_ignore)
		var tick = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 3)
		tick.set_source(self)
		Character.add_hostile_effect(context, user, target, tick)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Revenge Counter")

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
