extends Ability
var base_damage = 20

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ichigo deals 20 damage to one enemy. This skill will deal 5 additional damage every time it is used."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["+5 damage each time this skill affects an enemy (Stacks)", Color.CADET_BLUE],
		["While enhanced, this skill targets all enemies", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var damage_type = DamageType.Type.NORMAL
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, damage_type)
	if user.marked_by("Bankai: Tensa Zangetsu"):
		user.manually_advance_mission(9, 1)
	
	for i in range(len(user.targeter.targets)):
		var boost = Effect.damage_mod_effect(5, -1, ["Zangetsu Slash"])
		boost.set_source(self)
		boost.stackable = true
		boost.per_stack = true
		boost.display_stacks = true
		Character.add_allied_effect(context, user, user, boost)

func custom_behavior(context):
	var variations = []
	if target_type() == TargetType.Type.SINGLE:
		variations += behavior_single_target_damage(context, 35)
	else:
		variations += behavior_hostile_aoe_damage(context, 40)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
