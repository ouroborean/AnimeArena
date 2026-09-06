extends Ability
var base_damage = 15

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 damage to one enemy, stuns their non-Mental skills and marks them for 1 turn. Swaps to Judgement Chain for 1 turn."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		"Stuns their non-Mental skills and marks them for 1 turn",
		["Swaps to Judgement Chain for 1 turn", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
		var stun = Effect.stun_effect(3, [], ["Mental"])
		stun.set_source(self)
		stun.description = func (eff):
			return "This character's non-Mental skills are stunned and they can be targeted by Judgement Chain."
		
		Character.add_hostile_effect(context, user, target, stun)
	var swap = Effect.ability_swap_effect(4, 1, user, 3)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 75)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
