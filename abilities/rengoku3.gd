extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For one turn, the first harmful skill used on your team will be countered. If triggered, the enemy team is Shattered for 1 turn."

func split_desc():
	return [
		"For 1 turn, the first Harmful skill used on Rengoku's team is countered",
		["If triggered, the enemy team is Shattered for 1 turn", Color.ORANGE_RED],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter_eff = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, func (eff): return "The first harmful skill used on this character will be countered. If triggered, the enemy team will be Shattered for 1 turn.")
		counter_eff.set_source(self)
		counter_eff.invisible = true
		counter_eff.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, counter_eff)

func counter_trigger(context):
	var rengoku = context['effect'].user
	var attacker = context['owner']
	default_counter_trigger(context)
	
	for character in rengoku.team.characters:
		character.effects.remove_effect("Fourth Form: Blooming Flame Undulation", EffectType.Type.COUNTER_RECEIVE, rengoku)
	
	for character in attacker.team.characters:
		if not character.dead and not character.banished:
			var shatter = Effect.def_negate(2)
			shatter.set_source(self)
			Character.add_hostile_effect(context, rengoku, character, shatter, true)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_helpful_aoe_aid(context, 50, 1.2)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
