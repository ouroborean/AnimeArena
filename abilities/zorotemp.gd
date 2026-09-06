extends Ability

var base_damage = 25


#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 piercing damage to one enemy and grants Zoro 10 Shield for 1 turn. Swaps to 'Three-Sword Style Slicing'."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 25, DamageType.Type.PIERCING)
	var shield_eff = Effect.shield_effect(10, 2)
	shield_eff.set_source(self)
	var ability_swap = Effect.ability_swap_effect(5, 0, user, -1)
	ability_swap.set_source(self)
	
	ability_swap.unique_render_id = 1
	user.effects.remove_effect("Onigiri", EffectType.Type.ABILITY_SWAP, user)
	
	Character.add_allied_effect(context, user, user, shield_eff)
	Character.add_allied_effect(context, user, user, ability_swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 55)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
