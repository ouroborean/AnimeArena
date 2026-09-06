extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, if target enemy uses a new Strategic skill, they will be countered",
		["This also counters Mental skills, non-Mental skills, and the first skill used by the target's allies if Tokoyami has 1, 2, or 3 stacks of Black Abyss", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mag = 0
	if user.has_effect("Black Abyss", EffectType.Type.MARK):
		mag = user.has_effect("Black Abyss", EffectType.Type.MARK).mag
	if mag == 3:
		user.manually_advance_mission(8, 1)
	for target in user.targeter.targets:
		match mag:
			0:
				var counter = Effect.counter_effect(Trigger.always(default_counter_trigger), EffectType.Type.COUNTER_USE, 2, "The first Strategic skill used by this character will be countered.", ["Strategic"])
				counter.set_source(self)
				counter.invisible = true
				counter.wrapup_func = default_counter_timeout
				Character.add_hostile_effect(context, user, target, counter)
			1:
				var counter = Effect.counter_effect(Trigger.always(default_counter_trigger), EffectType.Type.COUNTER_USE, 2, "The first Strategic or Mental skill used by this character will be countered.", ["Strategic", "Mental"])
				counter.set_source(self)
				counter.invisible = true
				counter.wrapup_func = default_counter_timeout
				Character.add_hostile_effect(context, user, target, counter)
			2:
				var counter = Effect.counter_effect(Trigger.always(default_counter_trigger), EffectType.Type.COUNTER_USE, 2, "The first skill used by this character will be countered.")
				counter.set_source(self)
				counter.invisible = true
				counter.wrapup_func = default_counter_timeout
				Character.add_hostile_effect(context, user, target, counter)
			3:
				var counter = Effect.counter_effect(Trigger.always(default_counter_trigger), EffectType.Type.COUNTER_USE, 2, "The first skill used by this character will be countered.")
				counter.set_source(self)
				counter.invisible = true
				counter.wrapup_func = default_counter_timeout
				Character.add_hostile_effect(context, user, target, counter)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	var mag = 0
	if user.has_effect("Black Abyss", EffectType.Type.MARK):
		mag = user.has_effect("Black Abyss", EffectType.Type.MARK).mag
	
	if mag != 3:
		variations += behavior_single_target_damage(context, 25)
	else:
		variations += behavior_hostile_aoe_damage(context, 40)
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
 
