extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target character is marked for 3 turns. During this time, your opponent cannot see changes made to their HP",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hisoka_freeze = Effect.hisoka_health_freeze_effect()
		hisoka_freeze.set_source(self)
		hisoka_freeze.invisible = true
		hisoka_freeze.wrapup_func = texture_timeout
		if target in user.team.characters:
			Character.add_allied_effect(context, user, target, hisoka_freeze)
		else:
			Character.add_hostile_effect(context, user, target, hisoka_freeze)

func texture_timeout(context):
	var effect = Effect.invisible_expiration_effect(self)
	effect.set_source(self)
	Character.add_allied_effect(context, context['effect'].user, context['target'], effect)
	context.target.health.health_changed.emit(context.target.health.hp)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_any_target(context, 15)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
