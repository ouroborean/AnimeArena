extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Heals another ally 15 HP",
		["Until this skill is used again, Saturn Crystal will only target that ally (if it is currently targeting allies)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in user.team.characters:
		if character.marked_by("Silence Glaive Surprise"):
			character.effects.remove_effect("Silence Glaive Surprise", EffectType.Type.MARK)
	for target in user.targeter.targets:
		Character.resolve_healing(context, target, 15)
		var mark = Effect.mark(-1, "If Saturn Crystal is targeting allies, it can only target this ally.")
		mark.set_source(self)
		mark.cleansable = false
		Character.add_allied_effect(context, user, target, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
	
