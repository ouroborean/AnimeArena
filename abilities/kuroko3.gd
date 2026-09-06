extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "One enemy becomes Shattered for two turns. If used on the turn after Teleporting Strike, this skill Bypasses and deals 20 piercing damage to its target. If used on the turn after Judgement Throw, this skill will Isolate its target for one turn."

func split_desc():
	return [
		"Shatters target enemy for 2 turns",
		["Bypasses and deals 20 piercing damage if used the turn after Teleporting Strike", Color.CADET_BLUE],
		["Also Isolates the target for 1 turn if used the turn after Judgement Throw", Color.CADET_BLUE],
		["Afterward, Judgement Throw removes 1 energy from its target and Teleporting Strike has no cooldown", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var bypassing = false
	if user.marked_by("Teleporting Strike", user):
		bypassing = true
	for target in user.targeter.targets:
		var shatter = Effect.def_negate(3)
		shatter.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter, bypassing)
		if user.marked_by("Teleporting Strike", user):
			Character.resolve_damage(context, target, 20, DamageType.Type.PIERCING)
		if user.marked_by("Judgement Throw", user):
			var isolate = Effect.isolate(2)
			isolate.set_source(self)
			Character.add_hostile_effect(context, user, target, isolate, bypassing)
	var mark = Effect.mark(3, "Judgement Throw will remove 1 energy from its target and Teleporting Strike will have no cooldown.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
func custom_behavior(context):
	var kuroko = context['owner']
	var variations = []
	var bypassing = kuroko.marked_by("Teleporting Strike", kuroko)
	variations += behavior_single_target_damage(context, 0, 0.5, bypassing)
	
	return variations	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var bypassing = false
	if user.marked_by("Teleporting Strike", user):
		bypassing = true
	default_hostile_target_function(user, battle, bypassing)
