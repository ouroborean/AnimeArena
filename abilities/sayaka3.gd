extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For one turn, if target enemy uses a new damaging ability, it will heal instead of dealing damage. Invisible."

func split_desc():
	return [
		"For 1 turn, target enemy's next damaging skill will heal instead of dealing damage (Invisible)",
		["This healing counts as being caused by Sayaka", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var reverse_eff = Effect.from(EffectType.Type.DAMAGE_REVERSE, {"description": "If this character uses a new damaging skill, it will heal instead of dealing damage.", "duration": 2, "invisible": true})
		reverse_eff.set_source(self)
		reverse_eff.wrapup_func = default_counter_timeout
		Character.add_hostile_effect(context, user, target, reverse_eff)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 75)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
