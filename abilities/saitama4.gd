extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, the first non-strategic enemy harmful skill used on Saitama will be countered. If successful, Saitama gains 1 green energy, the enemy is marked, and this swaps to 'Serious Series: Serious Punch' for 1 turn. Invisible."

func split_desc():
	return [
		"Counters the first Harmful, non-Strategic skill used on Saitama for 1 turn (Invisible)",
		["If successful, Saitama gains 1 Green energy", Color.DIM_GRAY],
		["If successful, the countered enemy is marked and this skill swaps with Serious Series: Serious Punch", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var counter_eff = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "The first harmful, non-strategic skill used on Saitama will be countered. If successful, he will gain 1 green energy, mark the countered enemy, and swap Serious Series: Serious Side-Hops to Serious Series: Serious Punch for 1 turn.", ["Harmful"], ["Strategic"])
	counter_eff.wrapup_func = default_counter_timeout
	counter_eff.invisible=true
	counter_eff.set_source(self)
	Character.add_allied_effect(context, user, user, counter_eff)

func counter_trigger(context):
	var countered_target = context['owner']
	var counter_eff_target = context['target']
	var counter_user = context['effect'].user
	
	counter_user.gain_bonus_energy(Energy.Type.GREEN)
	
	var mark = Effect.mark(3, "This character can be targeted by Serious Series: Serious Punch.")
	mark.set_source(self)
	Character.add_hostile_effect(context, counter_user, countered_target, mark)
	
	var swap = Effect.ability_swap_effect(4, 2, counter_user, 2)
	swap.set_source(self)
	Character.add_allied_effect(context, counter_user, counter_user, swap)
	
	default_counter_trigger(context)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0, 2.0)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	default_self_target_function(user, battle)
