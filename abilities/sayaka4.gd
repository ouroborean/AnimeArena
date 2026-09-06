extends Ability

var base_damage = 25

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 piercing damage to one enemy. This skill cannot deal less than 20 damage. Uncounterable, Bypassing. Grants Sayaka one stack of Soul Gem: Sayaka."

func split_desc():
	return [
		"Deals 25 Piercing damage to target enemy and stuns Sayaka's Strategic skills for 1 turn (Bypasses)",
		["Cannot deal less than 20 damage", Color.CADET_BLUE],
		["Gives Sayaka 2 stacks of Soul Gem: Sayaka", Color.DIM_GRAY]
	]

func execute(user, battle):
	minimum_damage = 20
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	var stun = Effect.stun_effect(3, ["Strategic"])
	stun.set_source(self)
	Character.add_allied_effect(context, user, user, stun)
	if user.path_name == "sayaka":
		# Two SEPARATE single-stack grants, not a stack of 2: gain_corruption runs the death check
		# after each one, so Sayaka dies ON reaching her limit and is never left standing one stack
		# past it. (It also takes no arguments — calling it twice is the whole implementation.)
		user.gain_corruption()
		if not user.dead:
			user.gain_corruption()
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 20, 1.2, true)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
