extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Orihime and target ally gain 25 Shield for 1 turn",
		["While Empowered, any remaining Shield will heal its target upon expiration", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var shield = Effect.shield_effect(25, 2)
		shield.set_source(self)
		Character.add_allied_effect(context, user, target, shield)
		if user.marked_by("Six Princess Shielding Flowers"):
			user.manually_advance_mission(7, 1)
			shield.wrapup_func = healing_wrapup_func
	if not user in user.targeter.targets:
		var shield = Effect.shield_effect(25, 2)
		shield.set_source(self)
		Character.add_allied_effect(context, user, user, shield)
		if user.marked_by("Six Princess Shielding Flowers"):
			shield.wrapup_func = healing_wrapup_func

func healing_wrapup_func(context):
	var shield = context.effect
	if shield.mag > 0:
		Character.resolve_effect_healing(context, context.effect, context.target, shield.mag)
		

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_selfless_helpful(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
