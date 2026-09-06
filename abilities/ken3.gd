extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Kaneki ignores Harmful, non-damaging effects and gains 5 Damage Reduction for 3 turns. During this time, Tentacle Pierce and Disembowel will target 2 enemies at random"

func split_desc():
	return [
		"For 3 turns, Ken ignores Harmful non-damaging effects and gains 5 Damage Reduction",
		["During this time, Tentacle Pierce and Disembowel target 2 enemies at random", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var non_ignore = Effect.ignore_non_damage_effect(6)
	non_ignore.set_source(self)
	var mark = Effect.mark(5, "Tentacle Pierce and Disembowel will target 2 enemies at random.")
	mark.set_source(self)
	var dr = Effect.damage_reduction_effect(5, 6)
	dr.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, non_ignore)
	Character.add_allied_effect(context, user, user, dr)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []

	variations += behavior_self_panic_button(context, 150)

	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
