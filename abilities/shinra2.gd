extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 damage to one enemy and Taunts them for 1 turn."

func split_desc():
	return [
		"Deals 25 damage to one enemy",
		["Taunts the target for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var taunt = Effect.taunt_effect(2, user)
		taunt.set_source(self)
		Character.add_hostile_effect(context, user, target, taunt)
		if user.marked_by("Ignition: Shinra", user):
			var affliction = Effect.damage_effect(5, DamageType.Type.AFFLICTION, -1)
			affliction.set_source(user.moveset.base_abilities[0])
			affliction.stackable = true
			affliction.remove_on_death = false
			affliction.display_stacks = true
			affliction.per_stack = true
			Character.add_hostile_effect(context, user, target, affliction)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35, 1.4)
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
