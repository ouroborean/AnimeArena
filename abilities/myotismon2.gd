extends Ability
var base_damage = 40
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 40 damage to target enemy. If they are marked by Grisly Wing, they will permanently ignore healing effects."

func split_desc():
	return [
		"Deals 40 damage to target enemy",
		["If they are marked by Grisly Wing, they permanently ignore healing effects", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		if target.marked_by("Grisly Wing"):
			user.manually_advance_mission(7, 1)
			var heal_ignore = Effect.ignore_healing(-1)
			heal_ignore.set_source(self)
			Character.add_hostile_effect(context, user, target, heal_ignore)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 45)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
