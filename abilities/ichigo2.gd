extends Ability
var base_damage = 35
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ichigo deals 35 piercing damage to one enemy. For 1 turn, Ichigo becomes invulnerable to non-Strategic skills and gains 1 random energy. This skill will deal 5 additional damage for each time 'Hollow Slayer' and 'Getsuga Tenshou' were used."

func split_desc():
	return [
		"Deals 35 Piercing damage to one enemy",
		["When enhanced, Bypasses Invulnerability", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.marked_by("Bankai: Tensa Zangetsu"):
		user.manually_advance_mission(9, 1)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)


func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 45)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var bypassing = false
	if user.marked_by("Bankai: Tensa Zangetsu"):
		bypassing = true
	default_hostile_target_function(user, battle, bypassing)
