extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, Tanjiro targets his team and counters the first Harmful non-Strategic skill used on them. Countered enemies will take 5 more damage from Eighth Form: Waterfall Basin, and it will deal piercing damage to them. This skill is invisible and swaps with Eight Form: Waterfall Basin."

func split_desc():
	return [
		"Counters the first Harmful non-Strategic skill used on Tanjiro's team for 1 turn",
		["Countered enemies take 5 more damage from Eighth Form: Waterfall Basin, dealt as Piercing", Color.ORANGE_RED],
		["Invisible", Color.DIM_GRAY],
		["Swaps with Eighth Form: Waterfall Basin", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter_eff = Effect.counter_effect(Trigger.always(ripple_counter), EffectType.Type.COUNTER_RECEIVE, 2, "The first Harmful non-Strategic skill used on this character will be countered.", ["Harmful"], ["Strategic"])
		counter_eff.invisible = true
		counter_eff.wrapup_func = default_counter_timeout
		counter_eff.set_source(self)
		Character.add_allied_effect(context, user, target, counter_eff)

func ripple_counter(context):
	var countered_target = context['owner']
	var counter_eff_target = context['target']
	var counter_user = context['effect'].user
	var mark = Effect.vulnerability_effect(5, 6, ["Eighth Form: Waterfall Basin"])
	mark.description = func (eff):
		return "This character will take 5 more damage from Eighth Form: Waterfall Basin and it will deal Piercing damage to them."
	mark.set_source(self)
	Character.add_hostile_effect(context, counter_user, countered_target, mark)
	default_counter_trigger(context)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_helpful_aoe_aid(context, 25, 1.1)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
