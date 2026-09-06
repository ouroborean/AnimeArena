extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Kakashi targets himself or a selected ally for 1 turn. The next harmful skill is used on him will be countered and the countered enemy will take 25 piercing damage. Invisible."

func split_desc():
	return [
		"For 1 turn, the next Harmful skill used on Kakashi or the chosen ally is countered",
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Trigger.from_condition(Condition.always(), default_counter_trigger)
		var desc = func (eff):
			return "The first harmful ability used against this character will be countered."
		var effect = Effect.counter_effect(trigger, EffectType.Type.COUNTER_RECEIVE, 2, desc, ["Harmful"])
		effect.invisible = true
		effect.wrapup_func = default_counter_timeout
		effect.set_source(self)
		Character.add_allied_effect(context, user, target, effect)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	default_allied_target_function(user, battle)
