extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target enemy deals -5 non-Affliction damage for 4 turns (refreshes)",
		["While active, Ban deals +5 damage with his skills (stacks)", Color.CADET_BLUE],
		["Swaps to Hunter Festival", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var damage_mod = Effect.damage_mod_effect(-5, 8, [], [], [DamageType.Type.AFFLICTION])
		damage_mod.set_source(self)
		damage_mod.refresh = true
		Character.add_hostile_effect(context, user, target, damage_mod)
	var damage_boost = Effect.damage_mod_effect(5, 9)
	damage_boost.set_source(self)
	damage_boost.stackable = true
	damage_boost.display_stacks = true
	damage_boost.stack_mag = true
	Character.add_allied_effect(context, user, user, damage_boost)
	var swap = Effect.ability_swap_effect(4, 0, user, -1)
	swap.set_source(self)
	swap.unique_render_id = 5
	Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
