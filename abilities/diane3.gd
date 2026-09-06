extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 2 turns, all characters gain 15 damage reduction. During this time, this skill is replaced by Ground Gladius."


func split_desc():
	return [
		"Gives all characters 15 Damage Reduction for 2 turns",
		["Swaps to Ground Gladius while active", Color.AQUAMARINE],
		"Lasts 1 more turn each time Diane uses Diane Dance"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var duration = 4
	if user.marked_by("Diane Dance", user):
		duration = 4 + (user.has_effect("Diane Dance", EffectType.Type.MARK, user).stacks * 2)
	for target in user.targeter.targets:
		
		var dr = Effect.damage_reduction_effect(15, duration)
		dr.set_source(self)
		
		if target in context['enemy_team'].characters:
			Character.add_hostile_effect(context, user, target, dr)
			var mark = Effect.mark(duration, "Ground Gladius can target this character.")
			mark.set_source(self)
			Character.add_hostile_effect(context, user, target, mark)
		else:
			Character.add_allied_effect(context, user, target, dr)
	var swap = Effect.ability_swap_effect(4, 2, user, duration + 1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
