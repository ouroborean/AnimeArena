extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Misaka deals 25 damage to one enemy. This ability ignores invulnerability and cannot be countered or reflected. After being used, this ability will be replaced by Ultra Railgun for 1 turn."

func split_desc():
	return [
		"Deals 25 damage to target enemy, Bypassing Invulnerability",
		["Cannot be countered or reflected", Color.DIM_GRAY],
		["Replaced by Ultra Railgun for 1 turn after use", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var mod_damage = base_damage
	if user.marked_by("Ultra Railgun", user):
		mod_damage = mod_damage * 2
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.NORMAL)
	
	if not user.marked_by("Ultra Railgun", user) and not user.marked_by("Iron Colossus", user):
		var swap = Effect.ability_swap_effect(5, 1, user, 3)
		swap.set_source(self)
		Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	if target_type() == TargetType.Type.SINGLE:
		variations += behavior_single_target_damage(context, 35, 1.0, true)
	else:
		variations += behavior_hostile_aoe_damage(context, 50, 1.2, true)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
