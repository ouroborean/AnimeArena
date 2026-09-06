extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 Piercing damage to the enemy team. Deals up to 15 more damage based on the amount of Damage Reduction each enemy has. Swaps with Rankyaku Gaicho on use."

func split_desc():
	return [
		"Deals 15 Piercing damage to all enemies",
		["Up to 15 more damage based on each enemy's Damage Reduction", Color.CADET_BLUE],
		["Swaps with Rankyaku Gaicho on use", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var damage = 15
		var dr_effects = target.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)
		var total_dr = 0
		for dr in dr_effects:
			total_dr += dr.mag
		
		Character.resolve_damage(context, target, damage + total_dr, DamageType.Type.PIERCING)
	var swap = Effect.ability_swap_effect(5, 1, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
