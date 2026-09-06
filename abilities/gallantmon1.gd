extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Counters the first Harmful, non-Strategic skill used against one ally for 1 turn. If this skill expires without being triggered, it swaps to Shield of the Just for 1 turn. For 1 turn, Lightning Joust will strike twice."

func split_desc():
	return [
		"Counters the next Harmful, non-Strategic skill used against target ally for 1 turn",
		["Swaps to Shield of the Just for 1 turn if the counter fails", Color.AQUAMARINE],
		"Lightning Joust will strike twice next turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var thrust_mark = user.marked_by("Lightning Joust", user)
	
	for target in user.targeter.targets:
		if not thrust_mark:
			var counter = Effect.counter_effect(Trigger.always(default_counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "The first harmful non-Strategic skill used on this character will be countered.", ["Harmful"], ["Strategic"])
			counter.set_source(self)
			counter.invisible = true
			counter.wrapup_func = guard_timeout
			Character.add_allied_effect(context, user, target, counter)
		else:
			user.manually_advance_mission(9, 1)
			var reflect_eff = Effect.reflect_effect(Trigger.always(shield_reflect_trigger), EffectType.Type.REFLECT_RECEIVE, -1, 2, "The first harmful skill this character receives will be reflected back to the user.", ["Harmful"])
			reflect_eff.set_source(self)
			reflect_eff.invisible = true
			reflect_eff.wrapup_func = default_counter_timeout
			Character.add_allied_effect(context, user, target, reflect_eff)
	
	
	var mark = Effect.mark(3, "Lightning Joust will strike twice.")
	mark.set_source(self)
	mark.invisible = true
	Character.add_allied_effect(context, user, user, mark)
	

func shield_reflect_trigger(context):
	var attacker = context['owner']
	var ally = context['target']
	var gallant = context['effect'].user
	var tt = attacker.used_ability.target_type()
	if tt == TargetType.Type.SINGLE:
		attacker.targeter.targets.erase(attacker.targeter.main_target)
		attacker.targeter.targets.append(attacker)
	elif tt != TargetType.Type.SELF:
		# AoE reflected back to its user: re-aim onto the attacker's team.
		var valid = reflect_retarget_to_team(attacker)
		attacker.targeter.targets = valid
		attacker.targeter.main_target = valid[0]
	else:
		return

	ally.effects.remove_effect("Brave Shield", EffectType.Type.REFLECT_RECEIVE, gallant)
	

func guard_timeout(context):
	
	var gallant = context['effect'].user
	var swap = Effect.ability_swap_effect(4, 0, gallant, 2)
	swap.set_source(self)
	Character.add_allied_effect(context, gallant, gallant, swap)
	
	default_counter_timeout(context)

func shield_counter_trigger(context):
	pass

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 60)
	
	return variations
	
func target(user, battle):
	default_allied_target_function(user, battle)
