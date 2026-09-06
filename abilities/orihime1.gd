extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 Piercing damage to target enemy for 2 turns (Bypasses)",
		["While Empowered, deals 20 Piercing damage to all enemies (Bypasses)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if user.marked_by("Six Princess Shielding Flowers"):
			user.manually_advance_mission(7, 1)
			Character.resolve_damage(context, target, 20, DamageType.Type.PIERCING)
		else:
			Character.resolve_damage(context, target, 10, DamageType.Type.PIERCING)
			var damage = Effect.damage_effect(10, DamageType.Type.PIERCING, 3)
			damage.set_source(self)
			Character.add_hostile_effect(context, user, target, damage, true)
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	if user.marked_by("Six Princess Shielding Flowers"):
		variations += behavior_hostile_aoe_damage(context, 15, 1.0, true)
	else:
		variations += behavior_single_target_damage(context, 15, 1.0, true)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
